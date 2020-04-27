



CREATE PROC [dbo].[mmsACHEFTRecovery] (
  @RegionList VARCHAR(1000),
  @PaymentTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-------ACH EFT Recovery
--
---  Returns information on Bank Account type EFT drafts month to date;
---   whether or not they were initially rejected and if they are currently
---   recovered ( based upon the membership account balance).
-- parameters: Region, Payment Type
--

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Regions (Description VARCHAR(50))

       IF @RegionList <> 'All'
       BEGIN
           EXEC procParseStringList @RegionList
           INSERT INTO #Regions (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
       ELSE
       BEGIN
          INSERT INTO #Regions VALUES('All')
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

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = CASE WHEN @RegionList = 'All' THEN 'USD'
                                  ELSE (SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' 
                                                    ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
                                          FROM vClub C  
                                          JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
                                          JOIN #Regions ON VR.Description = #Regions.Description
                                          JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID) END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GetDate()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GetDate()) as varchar(4))
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GetDate()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GetDate()) as varchar(4))
  AND ToCurrencyCode = 'USD'
  


SELECT MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID,
       MMST.PostDateTime,
       MMST.TranAmount,
       MSB.CommittedBalance
INTO #MMSTran
FROM vMMSTran MMST WITH (NOLOCK)
JOIN vDrawerActivity DA
  ON MMST.DrawerActivityID = DA.DrawerActivityID
JOIN vMembershipBalance MSB
  ON MMST.MembershipID = MSB.MembershipID
WHERE DA.DrawerID = 25
  AND MMST.EmployeeID = -2
  AND MMST.ValTranTypeID = 4
  AND MMST.ReasonCodeID != 75
  AND (DATEDIFF(month,MMST.PostDateTime,GetDate()) = 0)
  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)


/***************************************/

   SELECT EFT.MembershipID, EFT.EFTDate, 
       VPT.Description AS EFTPaymentTypeDescription, 
       C.ClubName, 
       VES.Description AS EFTStatusDescription, 
       VR.Description AS RegionDescription,
       T1.PostDateTime AS ChargebackPostdatetime,       
       M.ExpirationDate,C.ClubID, VR.ValRegionID,GetDate() AS Today,
       Null AS RecurrentProductActivationDate,
       Null  AS RecurrentProductTerminationDate,
       Null  AS RecurrentProductDescription,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,
       MSB.CommittedBalance * #PlanRate.PlanRate as CommittedBalance,
       T1.TranAmount * #PlanRate.PlanRate as ChargebackTranAmount,
       EFT.EFTAmount as LocalCurrency_EFTAmount,
       MSB.CommittedBalance as LocalCurrency_CommittedBalance,
       T1.TranAmount as LocalCurrency_ChargebackTranAmount,
       EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,
       MSB.CommittedBalance * #ToUSDPlanRate.PlanRate as USD_CommittedBalance,
       T1.TranAmount * #ToUSDPlanRate.PlanRate as USD_ChargebackTranAmount,
       M.ValMembershipStatusID                     
/***************************************/

  FROM dbo.vEFT EFT
  JOIN vMembership M
       ON EFT.MembershipID = M.MembershipID
  JOIN dbo.vClub C
       ON M.ClubID = C.ClubID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType PT
       ON (VPT.Description = PT.Description OR PT.Description = 'All')
  JOIN dbo.vMembershipBalance MSB
       ON M.MembershipID = MSB.MembershipID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vValRegion VR 
       ON C.ValRegionID = VR.ValRegionID
  JOIN #Regions RS
       ON (VR.Description = RS.Description OR RS.Description = 'All')
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #ToUSDPlanRate.PlanYear
/*******************************************/

/* moved this subquery into #MMSTran declaration for performance reasons as part of the LFF Acquisition logic
   switched base view to vMMSTranNonArchive since report only returns results for the current month */
  --LEFT JOIN (
  --           SELECT MMST.MembershipID,MMST.ClubID,
  --                  MMST.PostDateTime, MMST.TranAmount, MSB.CommittedBalance
  --             FROM #MMSTran MMST
  --             JOIN dbo.vDrawerActivity DA
  --                  ON DA.DrawerActivityID = MMST.DrawerActivityID
  --             JOIN dbo.vMembershipBalance MSB 
  --                  ON MMST.MembershipID = MSB.MembershipID
  --            WHERE DA.DrawerID = 25 AND
  --                  MMST.EmployeeID = -2 AND
  --                  MMST.ValTranTypeID = 4 AND
  --                  MMST.ReasonCodeID != 75 AND
  --                  (DATEDIFF(month,MMST.PostDateTime,GETDATE()) = 0)
  --           ) T1
  LEFT JOIN #MMSTran T1
       ON T1.MembershipID = M.MembershipID AND
       C.ClubID = T1.ClubID
 WHERE EFT.EFTDate> = cast(DATEPART(month,GetDate()) as varchar(2))+'/01/'+cast(DATEPART(year,GetDate()) as varchar(4)) AND
       EFT.EFTDate< = cast(DATEPART(month,GetDate()) as varchar(2))+'/04/'+cast(DATEPART(year,GetDate()) as varchar(4))
       

       
  DROP TABLE #Regions
  DROP TABLE #PaymentType
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate
  DROP TABLE #MMSTran

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END





