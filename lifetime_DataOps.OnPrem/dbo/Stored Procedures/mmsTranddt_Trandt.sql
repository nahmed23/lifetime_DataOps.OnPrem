
CREATE   PROC [dbo].[mmsTranddt_Trandt](
            @ClubList VARCHAR(8000),
            @StartDate SMALLDATETIME,
            @EndDate SMALLDATETIME,
            @EmployeeList VARCHAR(1000),
            @TranTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- EXEC mmsTranddt_Trandt '141', 'Apr 1, 2011', 'Apr 2, 2011', 'All', 'Refund'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID INT)
       IF @ClubList <> 'All'
       BEGIN
         EXEC procParseStringList @ClubList
         INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
CREATE TABLE #Employee (EmployeeID VARCHAR(50))
       IF @EmployeeList <> 'All'
       BEGIN
         EXEC procParseStringList @EmployeeList
         INSERT INTO #Employee (EmployeeID) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
CREATE TABLE #TranType (Description VARCHAR(50))
       IF @TranTypeList <> 'All'
       BEGIN
         EXEC procParseStringList @TranTypeList
         INSERT INTO #TranType (Description) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
         ELSE
   INSERT INTO #TranType SELECT Description FROM dbo.Vvaltrantype


/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'
  
--LFF Acquisition changes begin
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID,
	ms.CreatedDateTime
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition
 
CREATE INDEX IX_MembershipID on #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)
 
SELECT 1497 MembershipTypeID
INTO #ProductIDs
UNION
SELECT 3100
UNION
SELECT MembershipTypeID
  FROM vMembershipTypeAttribute
 WHERE ValMembershipTypeAttributeID = 28
 
SELECT DISTINCT MMST.MMSTranID, 
	   CASE WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 160 THEN 220 --Cary
			WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 159 THEN 219 --Dublin
			WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 40  THEN 218 --Easton
			WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 30  THEN 214 --Indianapolis
			ELSE MMST.ClubID END ClubID,
	   MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
	   MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTran MMST
JOIN #Membership MS ON MMST.MembershipID = MS.MembershipID
LEFT JOIN vTranItem TI
  ON MMST.MMSTranID = TI.MMSTranID
 AND MMST.ValTranTypeID in (1,4) --LFF Acquisition logic
 AND TI.ProductID in (SELECT MembershipTypeID FROM #ProductIDs)
JOIN vValTranType VTT
  ON VTT.ValTranTypeID = MMST.ValTranTypeID
WHERE MMST.ClubID in (30,40,159,160) --LFF Acquisition logic
  AND MMST.PostDateTime > @StartDate
  AND MMST.PostDateTime < @EndDate
  AND (MMST.EmployeeID IN (Select EmployeeID from #Employee) OR @EmployeeList = 'All')
  AND VTT.Description IN (SELECT Description FROM #TranType)
UNION
SELECT DISTINCT MMST.MMSTranID, 
	   MMST.ClubID,
	   MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
	   MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
FROM vMMSTran MMST
JOIN vValTranType VTT
  ON VTT.ValTranTypeID = MMST.ValTranTypeID
WHERE MMST.ClubID not in (30,40,159,160)
  AND MMST.PostDateTime > @StartDate
  AND MMST.PostDateTime < @EndDate
  AND (MMST.EmployeeID IN (Select EmployeeID from #Employee) OR @EmployeeList = 'All')
  AND VTT.Description IN (SELECT Description FROM #TranType)
  
  
CREATE INDEX IX_ClubID on #MMSTran(ClubID)
CREATE INDEX IX_PostDateTime on #MMSTran(PostDateTime)
--LFF Acquisition changes end
/***************************************/

CREATE TABLE #TMPDiscount (
       TranItemID INT,
       ItemAmount MONEY,
       TotalDiscountAmount MONEY,
       ReceiptText1 VARCHAR(50),
       AppliedDiscountAmount1 MONEY,
       ReceiptText2 VARCHAR(50),
       AppliedDiscountAmount2 MONEY,
       ReceiptText3 VARCHAR(50),
       AppliedDiscountAmount3 MONEY,
       ReceiptText4 VARCHAR(50),
       AppliedDiscountAmount4 MONEY,
       ReceiptText5 VARCHAR(50),
       AppliedDiscountAmount5 MONEY)


DECLARE @TranItemID INT,
        @ItemAmount MONEY,
        @TotalDiscountAmount MONEY,
        @ReceiptText VARCHAR(50),
        @AppliedDiscountAmount MONEY,
        @HOLDTranItemID INT,
        @Counter INT

SET @HOLDTranItemID = -1
SET @Counter = 1


DECLARE Discount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT TI.TranItemID, TI.ItemAmount, TI.ItemDiscountAmount as TotalDiscountAmount,SP.ReceiptText,TID.AppliedDiscountAmount
  FROM #MMSTran MMST
  JOIN vTranItem TI
    ON MMST.MMSTranID = TI.MMSTranID
  JOIN vValTranType VTT
    ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN vTranItemDiscount TID
    ON TID.TranItemID = TI.TranItemID
  JOIN vPricingDiscount PD
    ON PD.PricingDiscountID = TID.PricingDiscountID
  JOIN vSalesPromotion SP
    ON PD.SalesPromotionID = SP.SalesPromotionID
 WHERE VTT.Description IN (Select Description from #TranType)
   AND MMST.PostDateTime >= @StartDate
   AND MMST.PostDateTime <= @EndDate
   AND (MMST.EmployeeID IN (Select EmployeeID from #Employee) OR @EmployeeList = 'All')
 ORDER BY TI.TranItemID, PD.SalesPromotionID



OPEN Discount_Cursor
FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN

        IF @TranItemID != @HOLDTranItemID
            BEGIN
                INSERT INTO #TMPDiscount
                   (TranItemID, ItemAmount, TotalDiscountAmount, ReceiptText1, AppliedDiscountAmount1)
                VALUES (@TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount)
                SET @HOLDTranItemID = @TranItemID
                SET @Counter = 1
            END
        ELSE
            BEGIN
                SET @Counter = @Counter + 1
                IF @Counter = 2
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText2 = @ReceiptText, AppliedDiscountAmount2 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 3
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText3 = @ReceiptText, AppliedDiscountAmount3 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 4
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText4 = @ReceiptText, AppliedDiscountAmount4 = @AppliedDiscountAmount
                          WHERE TranItemID = @TranItemID
                    END
                IF @Counter = 5
                    BEGIN
                        UPDATE #TMPDiscount SET ReceiptText5 = @ReceiptText, AppliedDiscountAmount5 = @AppliedDiscountAmount
                         WHERE TranItemID = @TranItemID
                    END
                SET @HOLDTranItemID = @TranItemID
            END

    FETCH NEXT FROM Discount_Cursor INTO @TranItemID,@ItemAmount,@TotalDiscountAmount,@ReceiptText,@AppliedDiscountAmount
    END

CLOSE Discount_Cursor
DEALLOCATE Discount_Cursor 

/********     3/11/2011 BSD ***************/
CREATE TABLE #PaymentTypeAmounts (MMSTranID INT, PaymentTypeAmount Varchar(1000))
DECLARE @MMSTranID INT,
        @PaymentType Varchar(50),
        @PaymentAmount Varchar(50),
        @CurrentMMSTranID INT
SET @CurrentMMSTranID = -1

 
DECLARE PaymentTypeAmount_Cursor CURSOR LOCAL READ_ONLY FOR
SELECT P.MMSTranID,PT.Description,Convert(Varchar,P.PaymentAmount)
FROM vPayment P
JOIN vValPaymentType PT ON P.ValPaymentTypeID=PT.ValPaymentTypeID
JOIN #MMSTran MMST ON P.MMSTranID = MMST.MMSTranID
JOIN vValTranType VTT ON VTT.ValTranTypeID = MMST.ValTranTypeID
JOIN #Membership MS ON MMST.MembershipID = MS.MembershipID
WHERE (CASE WHEN MMST.ClubID = 13 THEN MS.ClubID ELSE MMST.ClubID END in (SELECT ClubID FROM #Clubs) OR @ClubList = 'All') 
  AND VTT.Description IN (SELECT Description FROM #TranType) 
  AND MMST.PostDateTime BETWEEN @StartDate AND @EndDate 
  AND (MMST.EmployeeID IN (SELECT EmployeeID FROM #Employee) OR @EmployeeList = 'All')
ORDER BY MMSTranID

OPEN PaymentTypeAmount_Cursor
FETCH NEXT FROM PaymentTypeAmount_Cursor INTO @MMSTranID,@PaymentType,@PaymentAmount
WHILE (@@FETCH_STATUS = 0)
    BEGIN
		IF @MMSTranID = @CurrentMMSTranID
           BEGIN
                UPDATE #PaymentTypeAmounts
                   SET PaymentTypeAmount = PaymentTypeAmount + ', ' + @PaymentType + ' ' + @PaymentAmount
                 WHERE #PaymentTypeAmounts.MMSTranID = @MMSTranID
           END
        ELSE
           BEGIN
               INSERT INTO #PaymentTypeAmounts (MMSTranID, PaymentTypeAmount) VALUES (@MMSTranID, @PaymentType + ' ' + @PaymentAmount)
               SET @CurrentMMSTranID = @MMSTranID
           END
    FETCH NEXT FROM PaymentTypeAmount_Cursor INTO @MMSTranID,@PaymentType,@PaymentAmount
    END
CLOSE PaymentTypeAmount_Cursor
DEALLOCATE PaymentTypeAmount_Cursor 

SELECT --VR1.Description AS Region, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN VR1.Description ELSE TranItemRegion.Description END ELSE VR1.Description END AS Region,
       --C1.ClubName, 
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubName ELSE TranItemClub.ClubName END ELSE C1.ClubName END AS ClubName,
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       MMST.MemberID, MMST.TranAmount * #PlanRate.PlanRate as TranAmount, MMST.TranAmount as LocalCurrency_TranAmount,
	   MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
       MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    		
	   MMST.PostDateTime AS Postdate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as Postdate,    
	   P.DepartmentID,
       MMST.MMSTranID, TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount, 
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   TI.ItemSalesTax as LocalCurrency_ItemSalesTax, TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,	
       MMST.POSAmount * #PlanRate.PlanRate as POSAmount, MMST.POSAmount as LocalCurrency_POSAmount, 
	   MMST.POSAmount * #ToUSDPlanRate.PlanRate as USD_POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, 
       --MMST.ClubID AS TransactionClubID,
       CASE WHEN C1.ClubID = 9999 THEN CASE WHEN TI.ClubID IS NULL THEN C1.ClubID ELSE TranItemClub.ClubID END ELSE C1.ClubID END AS TransactionClubID,
       VR1.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
       VRC.description,
       MMST.MembershipID,
       P.GLAccountNumber,
       P.GLSubAccountNumber,
       GLA.DiscountGLAccount,
	   #TMP.TotalDiscountAmount * #PlanRate.PlanRate as TotalDiscountAmount,
	   #TMP.TotalDiscountAmount as LocalCurrency_TotalDiscountAmount,
	   #TMP.TotalDiscountAmount * #ToUSDPlanRate.PlanRate as USD_TotalDiscountAmount, 
	   #TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
       #TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
       #TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
       #TMP.AppliedDiscountAmount4 * #PlanRate.PlanRate as DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
       #TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
	   #TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,
	   #TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,                
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       DA.CloseDateTime DrawerCloseDateTime, --3/8/2011 BSD
	   #PaymentTypeAmounts.PaymentTypeAmount, --3/8/2011 BSD
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/

  FROM dbo.vClub C1
  JOIN #MMSTran MMST
       ON C1.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vDrawerActivity DA --3/8/2011 BSD
       ON MMST.DrawerActivityID = DA.DrawerActivityID --3/8/2011 BSD
  LEFT JOIN #PaymentTypeAmounts --3/8/2011 BSD
       ON MMST.MMSTranID = #PaymentTypeAmounts.MMSTranID --3/8/2011 BSD
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN #Membership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vClub TranItemClub
       ON TI.ClubID = TranItemClub.ClubID
  LEFT JOIN dbo.vValRegion TranItemRegion
       ON TranItemClub.ValRegionID = TranItemRegion.ValRegionID
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
  LEFT JOIN vGLAccount GLA
    ON P.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN #TMPDiscount  #TMP
    ON TI.TranItemID =  #TMP.TranItemID
 WHERE VTT.Description IN (SELECT Description FROM #TranType) AND
       (C1.ClubID IN (SELECT ClubID FROM #Clubs) OR
       @ClubList = 'All') AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       (E.EmployeeID IN (SELECT EmployeeID FROM #Employee) OR
       @EmployeeList = 'All')
       AND C1.ClubID not in(13)

UNION ALL

SELECT VR2.Description AS Region, 
       C2.ClubName, 
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       M.MemberID, MMST.TranAmount * #PlanRate.PlanRate as TranAmount, MMST.TranAmount as LocalCurrency_TranAmount,
	   MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
       MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(Convert(Varchar, MMST.TranDate ,22),2)) as TranDate,    		
	   MMST.PostDateTime AS Postdate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as Postdate,    
	   D.DepartmentID, MMST.MMSTranID, TI.ItemAmount * #PlanRate.PlanRate as ItemAmount, TI.ItemAmount as LocalCurrency_ItemAmount, 
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount, TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,
	   TI.ItemSalesTax as LocalCurrency_ItemSalesTax, TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax,	
       MMST.POSAmount * #PlanRate.PlanRate as POSAmount, MMST.POSAmount as LocalCurrency_POSAmount, 
	   MMST.POSAmount * #ToUSDPlanRate.PlanRate as USD_POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, C1.ClubID AS TransactionClubID,
       VR1.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,D.Description AS DeptDescription, 
       MS.CreatedDateTime AS MembershipCreatedDateTime,
	   E.EmployeeID as EmployeeNumber,
	   VRC.description,
       MMST.MembershipID,
       P.GLAccountNumber,
       P.GLSubAccountNumber,
       GLA.DiscountGLAccount,
	   #TMP.TotalDiscountAmount * #PlanRate.PlanRate as TotalDiscountAmount,
       #TMP.TotalDiscountAmount as LocalCurrency_TotalDiscountAmount,
	   #TMP.TotalDiscountAmount * #ToUSDPlanRate.PlanRate as USD_TotalDiscountAmount, 
	   #TMP.AppliedDiscountAmount1 * #PlanRate.PlanRate as DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 as LocalCurrency_DiscountAmount1,
	   #TMP.AppliedDiscountAmount1 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount1,
       #TMP.AppliedDiscountAmount2 * #PlanRate.PlanRate as DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 as LocalCurrency_DiscountAmount2,
	   #TMP.AppliedDiscountAmount2 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount2,
       #TMP.AppliedDiscountAmount3 * #PlanRate.PlanRate as DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 as LocalCurrency_DiscountAmount3,
	   #TMP.AppliedDiscountAmount3 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount3,
       #TMP.AppliedDiscountAmount4 * #PlanRate.PlanRate as DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 as LocalCurrency_DiscountAmount4,
	   #TMP.AppliedDiscountAmount4 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount4,
       #TMP.AppliedDiscountAmount5 * #PlanRate.PlanRate as DiscountAmount5,
	   #TMP.AppliedDiscountAmount5 as LocalCurrency_DiscountAmount5,
	   #TMP.AppliedDiscountAmount5 * #ToUSDPlanRate.PlanRate as USD_DiscountAmount5,   
       #TMP.ReceiptText1 as Discount1,
       #TMP.ReceiptText2 as Discount2,
       #TMP.ReceiptText3 as Discount3,
       #TMP.ReceiptText4 as Discount4,
       #TMP.ReceiptText5 as Discount5,
       DA.CloseDateTime DrawerCloseDateTime, --3/8/2011 BSD       
	   #PaymentTypeAmounts.PaymentTypeAmount, --3/8/2011 BSD
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode	   	
/***************************************/

  FROM dbo.vClub C1
  JOIN #MMSTran MMST
       ON C1.ClubID = MMST.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C1.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vDrawerActivity DA --3/8/2011 BSD
       ON MMST.DrawerActivityID = DA.DrawerActivityID --3/8/2011 BSD
  LEFT JOIN #PaymentTypeAmounts --3/8/2011 BSD
       ON MMST.MMSTranID = #PaymentTypeAmounts.MMSTranID --3/8/2011 BSD
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN #Membership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vReasonCode VRC
       ON	VRC.ReasonCodeID = MMST.ReasonCodeID
  LEFT JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  LEFT JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  LEFT JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  LEFT JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
  LEFT JOIN vGLAccount GLA
    ON P.GLAccountNumber = GLA.RevenueGLAccountNumber
  LEFT JOIN #TMPDiscount  #TMP
    ON TI.TranItemID =  #TMP.TranItemID
 WHERE MMST.ClubID in (13) AND
       (C2.ClubID IN (SELECT ClubID FROM #Clubs) OR
       @ClubList = 'All') AND
       VTT.Description IN (SELECT Description FROM #TranType) AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       (E.EmployeeID IN (SELECT EmployeeID FROM #Employee) OR
       @EmployeeList = 'All')

DROP TABLE #Clubs
DROP TABLE #Employee
DROP TABLE #TranType
DROP TABLE #tmpList
DROP TABLE #PaymentTypeAmounts
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #TMPDiscount
DROP TABLE #Membership
DROP TABLE #MMSTran

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
END
