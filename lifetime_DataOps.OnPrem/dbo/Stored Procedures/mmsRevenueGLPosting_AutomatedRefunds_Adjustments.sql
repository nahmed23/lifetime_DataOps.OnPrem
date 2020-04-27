




CREATE PROCEDURE [dbo].[mmsRevenueGLPosting_AutomatedRefunds_Adjustments]  (
    @ClubIDs VARCHAR(1000),
	@Month varchar(2), -- requested month
	@Year varchar(4)  -- requested year
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- EXECUTE mmsRevenueGLPosting_AutomatedRefunds_Adjustments '0', '3', '2011' 
--'6|35|11|175|189'

-- added 2 new parameters: month and year   --- RC 06/12/2009
--12/28/2011 BSD: Added LFF Acquisition logic


	-- Report Logging
	DECLARE @Identity AS INT
	INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
	SET @Identity = @@IDENTITY


	DECLARE @DateStart varchar(10)
	DECLARE @PostDateStart DATETIME
	DECLARE @PostDateEND DATETIME

    SET @DateStart = @Month +'/1/' + @Year
	SET @PostDateStart  =  cast(@DateStart as datetime)
	SET @PostDateEnd  =  dateadd(ss,-1,(dateadd(mm,1,@PostDateStart)))


--	DECLARE @FirstOfMonth DATETIME
--	-- prior month
--	SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
--	SET @PostDateStart  =  dateadd(mm,-1,@firstofmonth)
--	SET @PostDateEnd  =  dateadd(ss,-1,@firstofmonth)



	CREATE TABLE #tmpList(StringField VARCHAR(50))

	---- Parse the ClubIDs into a temp table
	EXEC procParseIntegerList @ClubIDs
	CREATE TABLE #Clubs(ClubID INT)
	INSERT INTO #Clubs(ClubID) SELECT StringField FROM #tmpList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #MonthlyPlanRate (MonthlyAverageExchangeRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), FirstOfMonthDate datetime, EndOfMonthDate datetime)
INSERT INTO #MonthlyPlanRate
SELECT MonthlyAverageExchangeRate, FromCurrencyCode, FirstOfMonthDate, EndOfMonthDate
FROM MonthlyAverageExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDMonthlyPlanRate (MonthlyAverageExchangeRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), FirstOfMonthDate datetime, EndOfMonthDate datetime)
INSERT INTO #ToUSDMonthlyPlanRate
SELECT MonthlyAverageExchangeRate, FromCurrencyCode, FirstOfMonthDate, EndOfMonthDate
FROM MonthlyAverageExchangeRate
WHERE ToCurrencyCode = 'USD'

--LFF Acquisition changes begin
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.MembershipTypeID,
	ms.ValMembershipStatusID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition


SELECT DISTINCT mt.MMSTranID, 
		CASE WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 160 THEN 220 --Cary
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 159 THEN 219 --Dublin
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 40  THEN 218 --Easton
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 30  THEN 214 --Indianapolis
			 ELSE mt.ClubID END ClubID,
	   mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.InsertedDateTime, mt.ComputerName, mt.IPAddress,
	   mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTran mt WITH (NOLOCK)
JOIN #Membership ms
  ON ms.MembershipID = mt.MembershipID
LEFT JOIN vTranItem ti WITH (NOLOCK)
  ON ti.MMSTranID = mt.MMSTranID
 AND mt.ValTranTypeID IN (1,4)
 AND mt.ClubID IN (30,40,159,160)
 AND (ti.ProductID IN (1497,3100)
		OR ti.ProductID IN (SELECT mta.MembershipTypeID 
							FROM vMembershipTypeAttribute mta WITH (NOLOCK)
							WHERE mta.ValMembershipTypeAttributeID = 28) --Acquisition
	 )
 WHERE mt.PostDateTime >= @PostDateStart --limit from result query
   AND mt.PostDateTime <= @PostDateEnd --limit from result query
   AND mt.ReasoncodeID = 108 --limit from result query
   AND mt.TranVoidedID is null --limit from result query

--LFF Acquisition changes end

/***************************************/

	CREATE TABLE #30DayRefundMembershipIDs (MembershipID int, ReportMonthYear varchar(50))

	INSERT INTO  #30DayRefundMembershipIDs 
	SELECT 
		Distinct(MMST.MembershipID) as MembershipID, 
		Datename(month, @PostDateStart) +' – '+ CONVERT(VARCHAR,Datepart(year, @PostDateStart)) as ReportMonthYear
	FROM vMMSTranRefund MMSTR
	JOIN #MMSTran MMST ON MMST.MMSTranID = MMSTR.MMSTranID
	JOIN vDrawerActivity DA ON DA.DrawerActivityID = MMST.DrawerActivityID 
	WHERE DA.ValDrawerStatusID = 3
	-- exclude voided transactions
	--MMST.TranVoidedID is null 
	-- transaction reason of “30 Day Cancellation” 
	--AND MMST.ReasoncodeID = 108 
	-- closed drawers only
	--AND 
	-- requested month
	--AND MMST.PostDateTime >= @PostDateStart AND MMST.PostDateTime <= @PostDateEnd

--LFF Acquisition changes Begin
SELECT DISTINCT mt.MMSTranID, 
		CASE WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 160 THEN 220 --Cary
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 159 THEN 219 --Dublin
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 40  THEN 218 --Easton
			 WHEN ti.MMSTranID IS NOT NULL AND ms.ClubID IN (214,218,219,220) AND mt.ClubID = 30  THEN 214 --Indianapolis
			 ELSE mt.ClubID END ClubID,
	   mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.InsertedDateTime, mt.ComputerName, mt.IPAddress,
	   mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID
  INTO #MMSTran30DayRefundMembershipIDs
  FROM vMMSTran mt WITH (NOLOCK)
  JOIN #30DayRefundMembershipIDs
    ON #30DayRefundMembershipIDs.MembershipID = mt.MembershipID
  JOIN #Membership ms
    ON ms.MembershipID = mt.MembershipID
LEFT JOIN vTranItem ti WITH (NOLOCK)
  ON ti.MMSTranID = mt.MMSTranID
 AND mt.ValTranTypeID IN (1,4)
 AND mt.ClubID IN (30,40,159,160)
 AND (ti.ProductID IN (1497,3100)
		OR ti.ProductID IN (SELECT mta.MembershipTypeID 
							FROM vMembershipTypeAttribute mta WITH (NOLOCK)
							WHERE mta.ValMembershipTypeAttributeID = 28) --Acquisition
	 )

--LFF Acquisition changes end
	SELECT 
		VR.Description as RegionDescription,
		C.GLClubID,
		C.ClubName, 
		VR.Description + ' Region - ' + C.ClubName as RegionClub,
		VTT.Description as TranTypeDescription,
		Sum(TI.ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate) as TotalItemAmount,
	    Sum(TI.ItemAmount) as LocalCurrency_TotalItemAmount,
		Sum(TI.ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate) as USD_TotalItemAmount,
		Sum(TI.ItemSalesTax * #MonthlyPlanRate.MonthlyAverageExchangeRate) as TotalItemSalesTax,
		Sum(TI.ItemSalesTax) as LocalCurrency_TotalItemSalesTax,
	    Sum(TI.ItemSalesTax * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate) as USD_TotalItemSalesTax,
		P.GLAccountNumber,
		P.GLSubAccountNumber,
		P.GLOverRideClubID,
		P.ProductID,
		P.Description as ProductDescription,
		CASE P.GLOverRideClubID WHEN 0 THEN Convert(varchar,C.GLClubID) +' - '+P.GLSubAccountNumber Else Convert(varchar,P.GLOverRideClubID)+' - '+P.GLSubAccountNumber END as PostingSubAccount,
		CASE WHEN Sum(TI.ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate) <= 0 Then ABS(sum(TI.ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate)) Else 0 end as Debit,
	    CASE WHEN Sum(TI.ItemAmount) <= 0 Then ABS(sum(TI.ItemAmount)) Else 0 end as LocalCurrency_Debit,
	    CASE WHEN Sum(TI.ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate) <= 0 Then ABS(sum(TI.ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate)) Else 0 end as USD_Debit,
		CASE WHEN Sum(TI.ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate) > 0 Then Sum(TI.ItemAmount * #MonthlyPlanRate.MonthlyAverageExchangeRate) Else 0 END as Credit,
		CASE WHEN Sum(TI.ItemAmount) > 0 Then Sum(TI.ItemAmount) Else 0 END as LocalCurrency_Credit,
		CASE WHEN Sum(TI.ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate) > 0 Then Sum(TI.ItemAmount * #ToUSDMonthlyPlanRate.MonthlyAverageExchangeRate) Else 0 END as USD_Credit,
		ReportMonthYear,
 /******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #MonthlyPlanRate.MonthlyAverageExchangeRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	
/***************************************/
		
	FROM #30DayRefundMembershipIDs MemIDs
	JOIN #MMSTran30DayRefundMembershipIDs MMST ON MMST.MembershipID = MemIDs.MembershipID
	JOIN #Clubs #C ON #C.ClubID = MMST.ClubID OR #C.ClubID = 0
	JOIN vClub C ON C.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #MonthlyPlanRate
       ON VCC.CurrencyCode = #MonthlyPlanRate.FromCurrencyCode
      AND MMST.PostDateTime >= #MonthlyPlanRate.FirstOfMonthDate
      AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= #MonthlyPlanRate.EndOfMonthDate
  JOIN #ToUSDMonthlyPlanRate
       ON VCC.CurrencyCode = #ToUSDMonthlyPlanRate.FromCurrencyCode
      AND MMST.PostDateTime >= #ToUSDMonthlyPlanRate.FirstOfMonthDate
      AND Convert(Datetime,Convert(Varchar,MMST.PostDateTime,101),101) <= #ToUSDMonthlyPlanRate.EndOfMonthDate
/*******************************************/
	JOIN vValRegion VR ON VR.ValRegionID = C.ValRegionID
	JOIN vTranItem TI ON TI.MMSTranID = MMST.MMSTranID 
	JOIN vProduct P ON P.ProductID = TI.ProductID
	JOIN vValTranType VTT ON VTT.ValTranTypeID = MMST.ValTranTypeID
	JOIN vReasonCode RC ON RC.ReasonCodeID = MMST.ReasonCodeID
	WHERE VTT.Description = 'Adjustment'
	GROUP BY 
		VR.Description,
		C.GLClubID,
		C.ClubName, 
		VR.Description + ' Region - ' + C.ClubName,
		VTT.Description,
		P.GLAccountNumber,
		P.GLSubAccountNumber,
		P.GLOverRideClubID,
		P.ProductID,
		P.Description,
		ReportMonthYear,
		VCC.CurrencyCode,
		#MonthlyPlanRate.MonthlyAverageExchangeRate


	DROP TABLE #30DayRefundMembershipIDs
	DROP TABLE #tmpList
	DROP TABLE #Clubs
	DROP TABLE #MonthlyPlanRate
	DROP TABLE #ToUSDMonthlyPlanRate
    DROP TABLE #MMSTran30DayRefundMembershipIDs
    DROP TABLE #mmstran
    DROP TABLE #membership

	-- Report Logging
    UPDATE HyperionReportLog
    SET EndDateTime = getdate()
    WHERE ReportLogID = @Identity

END
