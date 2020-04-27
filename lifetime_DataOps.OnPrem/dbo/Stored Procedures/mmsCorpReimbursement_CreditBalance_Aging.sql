
-- =============================================
-- Object:			mmsCorpReimbursement_CreditBalance_Aging
-- Author:			
-- Create date: 	
-- Description:		returns deliquent accounts within specified parameters 
--					Can be run to either display members who have paid LTF for 
--					services in advance (Credit Balances.
-- Parameters:		clubname, membership status, payment type, member type
-- Modified date:	1/21/2009 GRB: modified code to allow passage of ReimbursementProgramID instead
--					of ReimbursementProgramName, precipitated by inablitity to process value L'Oreal
--					because of it's embedded apostrophe;
-- 
-- EXEC mmsCorpReimbursement_CreditBalance_Aging 'Active|Late Activation|Non-Paid|Non-Paid, Late Activation|Pending Termination|Suspended|Terminated', '12'
-- =============================================

CREATE PROC [dbo].[mmsCorpReimbursement_CreditBalance_Aging] (
  @MembershipStatusList VARCHAR(1000),
  @ProgramIDs VARCHAR(1000)
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

CREATE TABLE #ProgramIDList (ProgramID VARCHAR(50))
EXEC procParseIntegerList @ProgramIDs
INSERT INTO #ProgramIDList (ProgramID)
SELECT StringField FROM #tmpList

TRUNCATE TABLE #tmpList

CREATE TABLE #MembershipStatus (Description VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatus (Description) 
SELECT StringField FROM #tmpList
           
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

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT RP.ReimbursementProgramName, VR.Description AS Region, C.ClubName,
       M.JoinDate, MR.EnrollmentDate, MR.TerminationDate, MR.MemberID,
       MSTAT.Description AS StatusDescription,
       MS.MembershipID, M.FirstName, M.MiddleName, M.LastName,
       MA.AddressLine1, MA.AddressLine2, MA.City, S.Abbreviation AS State, MA.Zip,
       MPN.HomePhoneNumber, M.EmailAddress,
       Sum(CASE P.Description When 'Enrollment Fee' Then TI.ItemAmount Else Null End) AS InitFee,
       Sum(CASE P.Description When 'Initiation Fee Rejoin' Then TI.ItemAmount Else Null End) AS InitReJoinFee,
       P2.Description as [Membership Type], CP.Price AS [Monthly_Dues],
       Case When M.ActiveFlag = 1 and MSTAT.Description <> 'Terminated' Then 'Active' Else 'Terminated' End as [Member Status],
       Case When MR.TerminationDate is Null Then 'Active' Else 'Terminated' End as [Program Status]
INTO #Reimbursement
FROM vReimbursementProgram RP
JOIN #ProgramIDList PL ON PL.ProgramID = RP.ReimbursementProgramID
JOIN vMemberReimbursement MR ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
JOIN vMember M ON MR.MemberID = M.MemberID
JOIN vMembership MS ON M.MembershipID = MS.MembershipID
JOIN vTranBalance TB ON TB.MembershipID = MS.MembershipID --ACME-08 11-6-2012
JOIN vValMembershipStatus MSTAT ON MS.ValMembershipStatusID = MSTAT.ValMembershipStatusID
JOIN #MembershipStatus MSS ON MSS.Description = MSTAT.Description
JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
JOIN vClub C ON MS.ClubID = C.ClubID
JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
JOIN vProduct P2 ON MST.ProductID = P2.ProductID
JOIN vClubProduct CP ON MST.ProductID = CP.ProductID
	AND MS.ClubID = CP.ClubID 
LEFT JOIN vMMSTran MMS ON MS.MembershipID = MMS.MembershipID
LEFT JOIN vTranItem TI ON MMS.MMSTranID = TI.MMSTranID
LEFT JOIN vProduct P ON TI.ProductID = P.ProductID
LEFT JOIN vMembershipAddress MA	ON MS.MembershipID = MA.MembershipID
LEFT JOIN vValState S ON MA.ValStateID = S.ValStateID
LEFT JOIN vMemberPhoneNumbers MPN ON MS.MembershipID = MPN.MembershipID
WHERE TB.TranBalanceAmount < 0 --ACME-08 11-6-2012
GROUP BY RP.ReimbursementProgramName, VR.Description, C.ClubName,
M.JoinDate, MR.EnrollmentDate, MR.MemberID, M.ValMemberTypeID, MS.MembershipID,
MSTAT.Description, M.FirstName, M.MiddleName, M.LastName,
MA.AddressLine1, MA.AddressLine2, MA.City, S.Abbreviation, MA.Zip,
MPN.HomePhoneNumber, M.EmailAddress, P2.Description, CP.Price,
M.ActiveFlag, MR.TerminationDate
ORDER BY RP.ReimbursementProgramName, MS.MembershipID, MR.MemberID

SELECT M.MemberID, TB.TranBalanceAmount, VEO.Description EFTOptionDesc, VPT.Description EFTPaymentMethodDescription,
       TB.TranItemID, MMST.TranDate, MMST.PostDateTime, RP.ReimbursementProgramID, CO.CompanyName, CO.CorporateCode
INTO #Delinquent
FROM vMembership MS 
JOIN vMember M ON MS.MembershipID = M.MembershipID
JOIN vValMembershipStatus VMSS ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
JOIN #MembershipStatus MSS ON VMSS.Description = MSS.Description 
JOIN vValEFTOption VEO ON VEO.ValEFTOptionID = MS.ValEFTOptionID
JOIN vTranBalance TB ON TB.MembershipID = MS.MembershipID
JOIN vMemberReimbursement MR ON MR.MemberID = M.MemberID
JOIN vReimbursementProgram RP ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
JOIN #ProgramIDList PL ON PL.ProgramID = RP.ReimbursementProgramID
LEFT JOIN vCompany CO ON RP.CompanyID = CO.CompanyID
LEFT JOIN vTranItem TI ON (TB.TranItemID = TI.TranItemID) 
LEFT JOIN vMMSTran MMST ON (TI.MMSTranID = MMST.MMSTranID)
LEFT JOIN vEFTAccountDetail EAD ON (MS.MembershipID = EAD.MembershipID) 
LEFT JOIN vValPaymentType VPT ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
WHERE TB.TranBalanceAmount < 0   

/*  ACME-08 11-6-2012  */
CREATE TABLE #HealthPartnerIDs (
MemberID INT, 
ReimbursementProgramID INT,
ReimbursementProgramName VARCHAR(50),
HealthPartnerID VARCHAR(303),
Part1FieldName VARCHAR(50),
Part1Value VARCHAR(100),
Part2FieldName VARCHAR(50),
Part2Value VARCHAR(100),
Part3FieldName VARCHAR(50),
Part3Value VARCHAR(100))

INSERT INTO #HealthPartnerIDs
SELECT #Delinquent.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       STUFF((SELECT ' ' + MRPIP.PartValue
                FROM vMemberReimbursementProgramIdentifierPart MRPIP
                JOIN vReimbursementProgramIdentifierFormatPart RPIFP
                  ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
               WHERE MR.MemberReimbursementID = MRPIP.MemberReimbursementID
               ORDER BY RPIFP.FieldSequence
               FOR XML PATH('')),1,1,'') AS HealthPartnerID,
       MAX(CASE WHEN RPIFP.FieldSequence = 1 THEN RPIFP.FieldName ELSE '' END) Part1FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 1 THEN MRPIP.PartValue ELSE '' END) Part1Value,
       MAX(CASE WHEN RPIFP.FieldSequence = 2 THEN RPIFP.FieldName ELSE '' END) Part2FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 2 THEN MRPIP.PartValue ELSE '' END) Part2Value,
       MAX(CASE WHEN RPIFP.FieldSequence = 3 THEN RPIFP.FieldName ELSE '' END) Part3FieldName,
       MAX(CASE WHEN RPIFP.FieldSequence = 3 THEN MRPIP.PartValue ELSE '' END) Part3Value
  FROM #Delinquent
  JOIN vMemberReimbursement MR
    ON #Delinquent.MemberID = MR.MemberID
   AND (MR.TerminationDate IS NULL OR MR.TerminationDate > GETDATE())
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN vMemberReimbursementProgramIdentifierPart MRPIP
    ON MR.MemberReimbursementID = MRPIP.MemberReimbursementID
  JOIN vReimbursementProgramIdentifierFormatPart RPIFP
    ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
 GROUP BY #Delinquent.MemberID, 
          RP.ReimbursementProgramID, 
          RP.ReimbursementProgramName, 
          MR.MemberReimbursementID
/****************************************************/

SELECT R.ReimbursementProgramName,
       R.Region,
       R.ClubName,
       R.JoinDate,
       R.EnrollmentDate,
       R.TerminationDate,
       R.MemberID,
       R.StatusDescription,
       R.MembershipID,
       R.FirstName,
       R.MiddleName,
       R.LastName,
       R.AddressLine1,
       R.AddressLine2,
       R.City,
       R.State,
       R.Zip,
       R.HomePhoneNumber,
       R.EmailAddress,
       R.[Membership Type],
       R.[Member Status],
       R.[Program Status],
       D.EFTOptionDesc, D.EFTPaymentMethodDescription,
	   D.TranItemID, D.TranDate, D.PostDateTime,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,	
	   R.InitFee * #PlanRate.PlanRate as InitFee,
	   R.InitFee as LocalCurrency_InitFee,
	   R.InitFee * #ToUSDPlanRate.PlanRate as USD_InitFee,
	   R.InitReJoinFee * #PlanRate.PlanRate as InitReJoinFee,	   
	   R.InitReJoinFee as LocalCurrency_InitReJoinFee,
	   R.InitReJoinFee * #ToUSDPlanRate.PlanRate as USD_InitReJoinFee,	
	   R.Monthly_Dues * #PlanRate.PlanRate as Monthly_Dues,   
	   R.Monthly_Dues AS LocalCurrency_Monthly_Dues,
	   R.Monthly_Dues * #ToUSDPlanRate.PlanRate AS USD_Monthly_Dues,	   
	   D.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	  
	   D.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	  
	   D.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount,
/***************************************/
       D.CompanyName as PartnerProgramCompanyName,
       D.CorporateCode as PartnerProgramCompanyCode,
       P1.Part1FieldName PartnerProgramIDPart1FieldName,
       P1.Part1Value PartnerProgramIDPart1Value,
       P1.Part2FieldName PartnerProgramIDPart2FieldName,
       P1.Part2Value PartnerProgramIDPart2Value,
       P1.Part3FieldName PartnerProgramIDPart3FieldName,
       P1.Part3Value PartnerProgramIDPart3Value
FROM #Reimbursement R
JOIN #Delinquent D ON R.MemberID = D.MemberID
/********** Foreign Currency Stuff **********/
  JOIN vClub C 
	   ON R.Clubname = C.ClubName
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
LEFT JOIN #HealthPartnerIDs P1
     ON D.MemberID = P1.MemberID
     AND D.ReimbursementProgramID = P1.ReimbursementProgramID

DROP TABLE #Reimbursement
DROP TABLE #Delinquent
DROP TABLE #MembershipStatus
DROP TABLE #ProgramIDList
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
