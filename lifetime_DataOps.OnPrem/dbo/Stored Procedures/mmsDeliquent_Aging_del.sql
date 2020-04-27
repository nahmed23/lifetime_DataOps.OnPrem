


-------------------------  Alter stored procedure mmsDeliquent_Aging_del  ------------------------- 

CREATE       PROC [dbo].[mmsDeliquent_Aging_del] (
  @ClubIDList VARCHAR(2000),
  @MemberTypeList VARCHAR(1000),
  @EmployeeOnlyFlag INT,
  @DisplayUIFlag INT,
  @PaymentTypeList VARCHAR(1000),
  @ReportType INT
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- returns deliquent accounts within specified parameters 
-- Can be run to either display members who owe LTF (Debit Balances ) or those 
-- who have paid LTF for services in advance (Credit Balances.
--
-- Parameters: clubids, membership status, payment type, member type
-- EXEC mmsDeliquent_Aging_del '141', 'Active','All','All','All'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(15))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs VALUES('All')
END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 'All'
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

CREATE TABLE #MemberType (Description VARCHAR(50))
       IF @MemberTypeList <> 'All'
       BEGIN
           EXEC procParseStringList @MemberTypeList
           INSERT INTO #MemberType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
       ELSE
	BEGIN
            INSERT INTO #MemberType VALUES('All')
	END
  
CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF @PaymentTypeList <> 'All'
       BEGIN
           EXEC procParseStringList @PaymentTypeList
           INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList

       END
            ELSE
	BEGIN
            INSERT INTO #PaymentType VALUES('All')
	END

 IF @ReportType = 1 --'Debit'
   BEGIN
   SELECT C.ClubName, VR.Description AS RegionDescription, P.Description AS MemberShipTypeDescription,
       M.MemberID, M.FirstName, M.LastName,
       MSP.AreaCode, MSP.Number, 
       VEO.Description AS EFTOptionDesc, VPT.Description AS EFTPaymentMethodDescription, 
       TB.TranItemID, MMST.TranDate, MMST.PostDateTime, GETDATE() AS QueryDate,
       VMSS.Description AS MemberShipStatusDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TB.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	   
	   TB.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	  
	   TB.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount,
       MB.EFTAmount * #PlanRate.PlanRate as MembershipBalanceAmount,
       MB.EFTAmount as LocalCurrency_MembershipBalanceAmount,
       MB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalanceAmount,
/***************************************/
       MS.CreatedDateTime as MembershipCreatedDate,
       M.JoinDate as PrimaryMemberJoinDate,
       VMS.Description as OriginalMembershipSalesChannel,
       M.EmailAddress as PrimaryMemberEMailAddress,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       MA.Zip,
       ST.Abbreviation as StateAbbreviation


  FROM dbo.vClub C
  JOIN dbo.vMembership MS 
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID OR CS.ClubID = 'All'
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID 
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN #MemberType MT
       ON VMSS.Description = MT.Description OR MT.Description = 'All'
  JOIN dbo.vValEFTOption VEO
       ON VEO.ValEFTOptionID = MS.ValEFTOptionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID
      AND P.ProductID = CP.ProductID
  JOIN dbo.vMembershipBalance MB
       ON M.MembershipID = MB.MembershipID
  LEFT OUTER JOIN dbo.vTranItem TI 
       ON (TB.TranItemID = TI.TranItemID) 
  LEFT OUTER JOIN dbo.vMMSTran MMST 
       ON (TI.MMSTranID = MMST.MMSTranID)
  LEFT OUTER JOIN dbo.vPrimaryPhone PP 
       ON (PP.MembershipID = MS.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipPhone MSP 
       ON (PP.MembershipID = MSP.MembershipID AND 
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID) 
  LEFT OUTER JOIN dbo.vEFTAccountDetail EAD 
       ON (MS.MembershipID = EAD.MembershipID) 
  LEFT OUTER JOIN dbo.vValPaymentType VPT 
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT OUTER JOIN dbo.vValMembershipSource VMS
       ON VMS.ValMembershipSourceID = MS.ValMembershipSourceID
  LEFT OUTER JOIN dbo.vMembershipAddress MA
       ON MA.MembershipID = MS.MembershipID
  LEFT OUTER JOIN dbo.vValState ST
       ON ST.ValStateID = MA.ValStateID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
    WHERE --(TB.TranBalanceAmount >= 15 OR TB.TranBalanceAmount >= CP.Price )AND
          (MB.EFTAmount >= 15 OR (MB.EFTAmount >= CP.Price AND MB.EFTAmount <>0)) AND
       M.ValMemberTypeID = 1 AND
       (C.DisplayUIFlag = 1 OR @DisplayUIFlag = 1 ) AND
       (P.Description LIKE '%Employee%' OR @EmployeeOnlyFlag = 0) AND
       (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')
       AND TI.TranItemID is Not Null
       AND DateDiff(Day,MMST.TranDate,GetDate()) <= 90
   END

Else --@ReportType = 'Credit'  -- 2
   BEGIN
   SELECT C.ClubName, VR.Description AS RegionDescription, P.Description AS MemberShipTypeDescription,
       M.MemberID, M.FirstName, M.LastName,
       MSP.AreaCode, MSP.Number,
       VEO.Description AS EFTOptionDesc, VPT.Description AS EFTPaymentMethodDescription, 
       TB.TranItemID, MMST.TranDate, MMST.PostDateTime, GETDATE() AS QueryDate,
       VMSS.Description AS MemberShipStatusDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TB.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	   
	   TB.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	  
	   TB.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount, 
 	   MB.EFTAmount * #PlanRate.PlanRate as MembershipBalanceAmount,
       MB.EFTAmount as LocalCurrency_MembershipBalanceAmount,
       MB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalanceAmount,
/***************************************/
       MS.CreatedDateTime as MembershipCreatedDate,
       M.JoinDate as PrimaryMemberJoinDate,
       VMS.Description as OriginalMembershipSalesChannel,
       M.EmailAddress as PrimaryMemberEMailAddress,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       MA.Zip,
       ST.Abbreviation as StateAbbreviation


  FROM dbo.vClub C
  JOIN dbo.vMembership MS 
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID OR CS.ClubID = 'All'
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID 
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN #MemberType MT
       ON VMSS.Description = MT.Description OR MT.Description = 'All'
  JOIN dbo.vValEFTOption VEO
       ON VEO.ValEFTOptionID = MS.ValEFTOptionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MB
       ON M.MembershipID = MB.MembershipID
  LEFT OUTER JOIN dbo.vTranItem TI 
       ON (TB.TranItemID = TI.TranItemID) 
  LEFT OUTER JOIN dbo.vMMSTran MMST 
       ON (TI.MMSTranID = MMST.MMSTranID)
  LEFT OUTER JOIN dbo.vPrimaryPhone PP 
       ON (PP.MembershipID = MS.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipPhone MSP 
       ON (PP.MembershipID = MSP.MembershipID AND 
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID) 
  LEFT OUTER JOIN dbo.vEFTAccountDetail EAD 
       ON (MS.MembershipID = EAD.MembershipID) 
  LEFT OUTER JOIN dbo.vValPaymentType VPT 
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT OUTER JOIN dbo.vValMembershipSource VMS
       ON VMS.ValMembershipSourceID = MS.ValMembershipSourceID
  LEFT OUTER JOIN dbo.vMembershipAddress MA
       ON MA.MembershipID = MS.MembershipID
  LEFT OUTER JOIN dbo.vValState ST
       ON ST.ValStateID = MA.ValStateID
       
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
    WHERE TB.TranBalanceAmount < 0 AND
       M.ValMemberTypeID = 1 AND
       (C.DisplayUIFlag = 1 OR @DisplayUIFlag = 1 ) AND
       (P.Description LIKE '%Employee%' OR @EmployeeOnlyFlag = 0) AND
       (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')
   END

DROP TABLE #Clubs
DROP TABLE #MemberType
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END


