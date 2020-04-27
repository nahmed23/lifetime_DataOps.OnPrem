
CREATE PROC [dbo].[mmsProjectedEFT_Detail] (
  @ClubIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
--	Object:			dbo.mmsProjectedEFT_Detail
--	Author:			
--	Create date: 	
--	Description:	
--	Modified date:	11/2/2009 GRB: added EFT Expiration Date per RR399; deploying on 11/4/2009 via dbcr_5173	
--					4/11/2011 SC: added support for foreign currency
--                  12/28/2011 BSD: Added LFF Acquisition logic

--	EXEC mmsProjectedEFT_Detail 'All'
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
   INSERT INTO #Clubs VALUES (0) -- all clubs
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
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = 'USD'


/***************************************/

SELECT C.ClubName, M.MemberID, M.FirstName,
	M.LastName, MSP.AreaCode, MSP.Number,
	M.JoinDate, 
C.ChargeToAccountFlag,
	C.ValStatementTypeID, VMS.Description MembershipStatusDescription,
	VR.Description RegionDescription,
	VPT.Description EFTPmtMethodDescription,
	GETDATE() as ReportDate,
	EAD.ExpirationDate,		-- added 11/2/2009 GRB
    CASE WHEN MONTH(MS.CreatedDateTime)= MONTH(GETDATE()) AND YEAR(MS.CreatedDateTime)= YEAR(GETDATE()) 
         THEN MS.CreatedDateTime 
         ELSE NULL 
         END MembershipCreatedDateTime,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	 
	   MSB.StatementBalance * #PlanRate.PlanRate as StatementBalance,  
	   MSB.EFTAmount * #PlanRate.PlanRate as EFTAmount,	   
	   MSB.CurrentBalance * #PlanRate.PlanRate as CurrentBalance,
	   MSB.StatementBalance as LocalCurrency_StatementBalance, 
	   MSB.EFTAmount as LocalCurrency_EFTAmount,	   
	   MSB.CurrentBalance as LocalCurrency_CurrentBalance,
	   MSB.StatementBalance * #ToUSDPlanRate.PlanRate as USD_StatementBalance,
	   MSB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,
	   MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_CurrentBalance	   	   	
/***************************************/

FROM dbo.vClub C
JOIN #Clubs CS
     ON C.ClubID = CS.ClubID or CS.ClubID = 0
JOIN vMembership MS
     ON MS.ClubID = C.ClubID
JOIN dbo.vMember M
     ON MS.MembershipID = M.MembershipID
JOIN dbo.vValRegion VR
     ON C.ValRegionID = VR.ValRegionID 
JOIN dbo.vValMembershipStatus VMS
     ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN dbo.vMembershipBalance MSB
	ON MS.MembershipID = MSB.MembershipID
JOIN vEFTAccountDetail EAD					-- added 11/2/2009 GRB 
	ON (MS.MembershipID = EAD.MembershipID)	-- added 11/2/2009 GRB
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
LEFT JOIN dbo.vPrimaryPhone PP
     ON PP.MembershipID = MS.MembershipID
LEFT JOIN dbo.vMembershipPhone MSP
     ON PP.MembershipID = MSP.MembershipID 
     AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID
LEFT JOIN dbo.vEFTAccountDetail EFTD
     ON MS.MembershipID = EFTD.MembershipID
LEFT JOIN dbo.vValPaymentType VPT
     ON EFTD.ValPaymentTypeID = VPT.ValPaymentTypeID

WHERE M.ValMemberTypeID = 1 AND
     C.DisplayUIFlag = 1 AND
     MS.ValEFTOptionID = 1 AND ----- ValEFTOptionID of 1 = 'Active EFT'
     MSB.EFTAmount > 0 
Order by VR.Description,C.ClubName,M.MemberID
    
  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

