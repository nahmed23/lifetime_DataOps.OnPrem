
CREATE PROC [dbo].[mmsEFTHistory] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @ClubIDList VARCHAR(2000),
  @MemberList VARCHAR(1000),
  @PaymentTypeList VARCHAR(1000),
  @AcctNumL4 VARCHAR(4),
  @AcctNumF6 VARCHAR(6)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:            dbo.mmsEFTHistory
-- Author:            
-- Create date:     
-- Description:        Returns EFT transaction Hx within selected parameters
-- Modified date:    7/15/2009 GRB: Updated to accept first six digits of Account Number with wildcard value of 'All';
--                 12/28/2011 BSD: Added LFF Acquisition logic
--     
-- Parameters:        clubid, member id, payment type, account number, startdate, endate

--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '3889', '83889'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '4925', '614925'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '5485', '115485'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '5673', '005456'
--Exec mmsEFTHistory '5/1/2005', '7/1/2005', 'All', 'All', 'All', '8962', 'NULL'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '4890', '060014'
--Exec mmsEFTHistory '5/1/2005', '7/1/2005', 'All', 'All', 'All', '7799', 'NULL'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '6738', '487534'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '4580', '013816'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '8732', '086307'
--Exec mmsEFTHistory '6/2/2007', '8/2/2007', 'All', 'All', 'All', '7166', '048946'
--    Exec mmsEFTHistory '6/1/2009', '6/30/2009', 'All', 'All', 'All', 'All', '428208'
--    Exec mmsEFTHistory '6/1/2009', '6/30/2009', 'All', 'All', 'All', '1000', '371509'
--    Exec mmsEFTHistory '6/1/2009', '6/30/2009', 'All', 'All', 'All', 'All', '512107'
--  Exec mmsEFTHistory 'Jan 1, 2013', 'Oct 1, 2013', 'All', '101112805', 'All', 'All', 'All'
-- =============================================

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(50))
    IF @ClubIDList <> 'All'
    BEGIN
           EXEC procParseStringList @ClubIDList
           INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
    END  
ELSE
BEGIN
   INSERT INTO #Clubs VALUES(0) -- all clubs
END  

CREATE TABLE #Member (Member VARCHAR(50))
       IF @MemberList <> 'All'
       BEGIN
           EXEC procParseStringList @MemberList
           INSERT INTO #Member (Member) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END 
    
CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF @PaymentTypeList <> 'All'
       BEGIN
           EXEC procParseStringList @PaymentTypeList
           INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0 
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


SELECT ms.MembershipID,
       ms.ClubID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
WHERE (ms.MembershipID IN (SELECT MembershipID 
                              FROM vMember 
                             WHERE MemberID IN (SELECT Member
                                                  FROM #Member)) OR @MemberList = 'All')


-- Chargebacks: this query returns data for a member only and not for a 
SELECT 
       Replace(Substring(convert(varchar,MMST.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMST.PostDateTime,100),8,4),'  ',' ') as PostDate,
       C.ClubName, 
       M.MemberID,
       M.FirstName, 
       M.LastName,       
       VPT.Description AS PaymentTypeDescription,
       VPT.ValPaymentTypeID,       
       VR.Description AS RegionDescription,           
       RC.Description AS ReasonCodeDescription, 
       MMST.PostDateTime,               
       VEO.Description AS EFTOptionDescription, 
       GETDATE() AS CurrentDate,       
 /******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MMST.TranAmount * #PlanRate.PlanRate as TranAmount,       
       MMST.TranAmount as LocalCurrency_TranAmount,       
       MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount            
/***************************************/ 
  INTO #Chargeback 
  FROM vMMSTran MMST
  JOIN dbo.vClub C
       ON MMST.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID  
  JOIN vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  JOIN #Member tM 
       ON M.MemberID = tM.Member  
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vValEFTOption VEO
       ON MS.ValEFTOptionID = VEO.ValEFTOptionID
/********** Foreign Currency Stuff **********/  
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN dbo.vEFTAccountDetail EAD
       ON (MS.MembershipID = EAD.MembershipID)
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  --LEFT JOIN vValEFTAccountType ACCT 
  --     ON VPT.ValEFTAccountTypeID = ACCT.ValEFTAccountTypeID
 WHERE DA.DrawerID = 25 AND
       MMST.EmployeeID = -2 AND
       MMST.ValTranTypeID = 4 AND
       --M.MemberID = @MemberID AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       MMST.ReasonCodeID != 75 

-- EFT Transactions
SELECT EFT.EFTDate, C.ClubName, M.MemberID,
       M.FirstName, M.LastName, EFT.MaskedAccountNumber AS AccountNumber,
       EFT.RoutingNumber, 
           
       VPT.Description AS PaymentTypeDescription,
       EFT.ValPaymentTypeID, 
       VR.Description AS RegionDescription,
       EFT.ValEFTStatusID,
       VES.Description AS EFTStatusDescription,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,
       EFT.EFTAmount as LocalCurrency_EFTAmount,       
       EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount                  
/***************************************/
  INTO #EFTTransaction
  FROM #Membership MS
  JOIN dbo.vEFT EFT
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID  
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EFT.ValPaymentTypeID = VPT.ValPaymentTypeID) 
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

 WHERE M.ValMemberTypeID = 1 AND
       (C.ClubID IN (SELECT ClubID FROM #Clubs) OR @ClubIDList = 'All') AND
       EFT.EFTDate BETWEEN @StartDate AND @EndDate AND
       (MS.MembershipID IN (SELECT MembershipID 
                              FROM dbo.vMember 
                             WHERE MemberID IN (SELECT Member
                                                  FROM #Member)) OR @MemberList = 'All') AND
    (
    (Left(EFT.MaskedAccountNumber64, LEN(@AcctNumF6))= @AcctNumF6 
    AND Right(EFT.MaskedAccountNumber, LEN(@AcctNumL4)) = @AcctNumL4)
    OR 
    (Left(EFT.MaskedAccountNumber64, LEN(@AcctNumF6))= @AcctNumF6        -- added GRB 7/15/2009
    AND @AcctNumL4 = 'All')                                                -- added GRB 7/15/2009
    OR
    (@AcctNumF6 = 'All'
    AND (Right(EFT.MaskedAccountNumber, LEN(@AcctNumL4)) = @AcctNumL4))
    OR 
    (@AcctNumF6 = 'All' AND @AcctNumL4 = 'All')
    ) AND
     (VPT.Description IN (SELECT Description FROM #PaymentType) OR @PaymentTypeList = 'All')

SELECT 
       EFTDate, 
	   ClubName, 
	   MemberID,
       FirstName, 
       LastName, 
       AccountNumber,
       RoutingNumber,            
       PaymentTypeDescription,       
       ValPaymentTypeID,       
       RegionDescription,       
       ValEFTStatusID,
       EFTStatusDescription,
       LocalCurrencyCode,
       PlanRate,
       ReportingCurrencyCode,
       EFTAmount,
       LocalCurrency_EFTAmount,       
       USD_EFTAmount   

FROM #EFTTransaction
UNION ALL
SELECT 
       PostDate,
       ClubName, 
       MemberID,
       FirstName, 
       LastName, 
       '' AS AccountNumber,
       '' AS RoutingNumber,         
       PaymentTypeDescription,
       ValPaymentTypeID, 
       RegionDescription, 
       '' ValEFTStatusID,
       ReasonCodeDescription,
       LocalCurrencyCode,
       PlanRate,           
       ReportingCurrencyCode,
       TranAmount * (-1),
       LocalCurrency_TranAmount * (-1),
       USD_TranAmount * (-1)
FROM #Chargeback   
ORDER BY RegionDescription, ValPaymentTypeID, PaymentTypeDescription, FirstName, LastName, EFTDate

DROP TABLE #Clubs
DROP TABLE #Member
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #EFTTransaction
DROP TABLE #Chargeback

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



