

CREATE PROC [dbo].[mmsDeliquent_CreditBalance_Scheduled](
             @RegionIDList VARCHAR(1000))

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- returns deliquent accounts for the supplied regions
-- for scheduled job processing

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
--Parse @RegionIDList
CREATE TABLE #tmpList(StringField INT)
EXEC procParseIntegerList @RegionIDList

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode
  AND PlanYear >= Year(dateadd(dd,-120,getdate()))
  AND PlanYear <= Year(dateadd(dd,-120,getdate())) + 1

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
  AND PlanYear >= Year(dateadd(dd,-120,getdate()))
  AND PlanYear <= Year(dateadd(dd,-120,getdate())) + 1
/***************************************/

SELECT C.ClubName, VR.Description AS RegionDescription, P.Description AS MemberShipTypeDescription,
       M.MemberID, REPLACE(M.FirstName,'''',' ')AS FirstName, REPLACE(M.LastName,'''','')AS LastName,
       MSP.AreaCode, MSP.Number, 
       VEO.Description AS EFTOptionDesc, VPT.Description AS EFTPaymentMethodDescription, 
       TB.TranItemID,
       VMSS.Description AS MemberShipStatusDescription,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TB.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	   
	   TB.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	   
	   TB.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount,
	   MMST.TranDate as TranDate_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.TranDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.TranDate ),5,DataLength(Convert(Varchar, MMST.TranDate))-12)),' '+Convert(Varchar,Year(MMST.TranDate)),', '+Convert(Varchar,Year(MMST.TranDate))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.TranDate,22),10,5) + ' ' + Right(ConverT(Varchar, MMST.TranDate ,22),2)) as TranDate,    
	   MMST.PostDateTime as PostDateTime_Sort, 
	   Replace(SubString(Convert(Varchar, MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MMST.PostDateTime ),5,DataLength(Convert(Varchar, MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + ' ' + LTRIM(SubString(Convert(Varchar, MMST.PostDateTime,22),10,5) + ' ' + Right(Convert(Varchar, MMST.PostDateTime ,22),2)) as PostDateTime,    
	   GETDATE() AS QueryDate_Sort,
	   Replace(SubString(Convert(Varchar, GETDATE()),1,3)+' '+LTRIM(SubString(Convert(Varchar, GETDATE() ),5,DataLength(Convert(Varchar, GETDATE()))-12)),' '+Convert(Varchar,Year(GETDATE())),', '+Convert(Varchar,Year(GETDATE()))) + ' ' + LTRIM(SubString(Convert(Varchar, GETDATE(),22),10,5) + ' ' + Right(ConverT(Varchar, GETDATE() ,22),2)) as QueryDate    
/***************************************/

  FROM dbo.vClub C
  JOIN dbo.vMembership MS 
       ON MS.ClubID = C.ClubID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID 
  JOIN #tmpList --Return results only for supplied RegionIDs
       ON VR.ValRegionID = #tmpList.StringField
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValEFTOption VEO
       ON VEO.ValEFTOptionID = MS.ValEFTOptionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
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
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GetDate()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GetDate()) = #ToUSDPlanRate.PlanYear
/*******************************************/
 WHERE TB.TranBalanceAmount < 0 AND
       M.ValMemberTypeID = 1

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

