
CREATE PROC [dbo].[mmsProjectedEFT_Summary] (
  @ClubIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Returns Summary of EFT details for a given clublist for the ProjectedEFT Brio bqy
--
-- Parameters: a | separated list of Clubnames
-- EXEC mmsProjectedEFT_Summary '141'

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
  
  SELECT C.ClubName, VR.Description RegionDescription,
         COUNT (DISTINCT (MS.MembershipID)) MembershipID, VPT.Description EFTPmtMethodDescription,
		 VMS.Description MembershipStatusDescription,
         GETDATE() ReportDate,
		CASE WHEN MONTH(MS.CreatedDateTime)= MONTH(GETDATE()) AND YEAR(MS.CreatedDateTime)= YEAR(GETDATE()) 
			 THEN MS.CreatedDateTime 
			 ELSE NULL 
			 END MembershipCreatedDateTime,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	 	     
	   SUM (MSB.EFTAmount * #PlanRate.PlanRate) as EFTAmount,	   	   	   
	   SUM (MSB.EFTAmount) as LocalCurrency_EFTAmount,	   	   
	   SUM (MSB.EFTAmount * #ToUSDPlanRate.PlanRate) as USD_EFTAmount  	   	
/***************************************/

    FROM dbo.vClub C
    JOIN #Clubs CS
         ON C.ClubID = CS.ClubID or CS.ClubID = 0
    JOIN vMembership MS
         ON MS.ClubID = C.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vMembershipBalance MSB
         ON MS.MembershipID = MSB.MembershipID
    JOIN dbo.vValMembershipStatus VMS
         ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
    LEFT JOIN dbo.vEFTAccountDetail EFTD
         ON MS.MembershipID = EFTD.MembershipID
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
    LEFT JOIN dbo.vValPaymentType VPT
         ON EFTD.ValPaymentTypeID = VPT.ValPaymentTypeID 

   WHERE C.DisplayUIFlag = 1 AND
         MS.ValEFTOptionID = 1 AND  ----ValEFTOptionID of 1 is "Active EFT"
         MSB.EFTAmount > 0
   GROUP BY C.ClubName, VCC.CurrencyCode, #PlanRate.PlanRate, VR.Description,VPT.Description ,
         VMS.Description, 
  		CASE WHEN MONTH(MS.CreatedDateTime)= MONTH(GETDATE()) AND YEAR(MS.CreatedDateTime)= YEAR(GETDATE()) 
			 THEN MS.CreatedDateTime 
			 ELSE NULL 
			 END
  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

