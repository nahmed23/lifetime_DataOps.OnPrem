



-- =============================================
--	Object:			dbo.mmsEFT_Expiration_Detail
--	Author:			Greg Burdick
--	Create date: 	10/28/2009 deploying 11/4/2009 via dbcr_5173
--	Description:	This procedure returns a list of 'Active', Primary Members associated with EFT Cards expiring in the specified Month and Year	
--	Modified date:	4/11/2011 SC: added support for foreign currency
--	
--  Exec mmsEFT_Expiration_Detail 'All', '11', '2011'
--	Exec mmsEFT_Expiration_Detail '14|153|158|10|149|195|151', 10, 2010
-- =============================================



CREATE     PROC [dbo].[mmsEFT_Expiration_Detail] (
	@ClubIDList VARCHAR(1000),
	@ExpirationMonth INT,
	@ExpirationYear INT
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

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
WHERE PlanYear = @ExpirationYear
AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = @ExpirationYear
AND ToCurrencyCode = 'USD'
/***************************************/

SELECT 
	MS.MembershipID, VMS.Description [MembershipStatusDescription], M.MemberID, 
	 -- EAD.ExpirationDate,
	M.JoinDate, C.ClubID, C.ClubName, C.ClubCode, C.FormalClubName,
	P.Description AS MembershipTypeDescription,
	M.FirstName, M.LastName, M.EmailAddress, M.DOB, M.Gender, 	
	VPT.Description [EFTPmtMethodDesc],
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MSB.EFTAmount * #PlanRate.PlanRate as EFTAmount,	   
	   MSB.EFTAmount as LocalCurrency_EFTAmount,	   
	   MSB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount	      	
/***************************************/

FROM dbo.vMember M
	JOIN vMembership MS ON MS.MembershipID = M.MembershipID
	JOIN vClub C ON MS.ClubID = C.ClubID
	JOIN #Clubs ON C.ClubID = #Clubs.ClubID or #Clubs.ClubID = 0
	JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
	JOIN vProduct P ON MST.ProductID = P.ProductID
	JOIN vValMembershipStatus VMS ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
    JOIN vMembershipBalance MSB ON MS.MembershipID = MSB.MembershipID	
	JOIN vEFTAccountDetail EAD ON (MS.MembershipID = EAD.MembershipID) 
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EAD.ExpirationDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(EAD.ExpirationDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
	LEFT OUTER JOIN vValPaymentType VPT ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)

WHERE VMS.ValMembershipStatusID NOT IN (1,2,3)	-- not terminated, suspended, or peding termination
	AND M.ValMemberTypeID = 1	-- Primary Members only
	AND MS.ValEFTOptionID = 1	-- ValEFTOptionID of 1 = 'Active EFT'
	AND MONTH(EAD.ExpirationDate) = @ExpirationMonth
	AND YEAR(EAD.ExpirationDate) = @ExpirationYear

ORDER BY ClubName, MembershipID, MemberID

DROP TABLE #Clubs
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
