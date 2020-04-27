
-- =============================================
-- Object:            mmsCorpReimbursement_Participation
-- Author:            
-- Create date:     
-- Description:        returns all current Corporate Wellness program reimbursement 
--                    participants within the selected program
-- Modified date:    9/17/2009 GRB: added Reimbursement Program Identifier Description and MonthlyDuesPlusTax
--                    columns per RR396; deploying via dbcr_5046 on 9/23/2009;
--                    1/21/2009 GRB: modified code to allow passage of ReimbursementProgramID instead
--                    of ReimbursementProgramName, precipitated by inablitity to process value L'Oreal
--                    because of it's embedded apostrophe;
-- 
--    EXEC mmsCorpReimbursement_Participation '12'
--    EXEC mmsCorpReimbursement_Participation '19'
-- =============================================

CREATE PROC [dbo].[mmsCorpReimbursement_Participation](
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

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
    ClubID INT, 
    ProductID INT, 
    TaxPercentage SMALLMONEY 
    )

INSERT INTO #ClubProductTaxRate 
    SELECT CPTR.ClubID, CPTR.ProductID, Sum(TR.TaxPercentage) AS TaxPercentage 
    FROM dbo.vClubProductTaxRate CPTR
    JOIN dbo.vTaxRate TR ON  TR.TaxRateID = CPTR.TaxRateID
    GROUP BY CPTR.ClubID, CPTR.ProductID

SELECT RP.ReimbursementProgramName, 
       RPIF.Description AS [Reimbursement Program Identifier Desc],
       VR.Description AS Region, C.ClubName,
       M.JoinDate, MR.EnrollmentDate, MR.TerminationDate AS [Program Termination Date],
       MS.ExpirationDate AS [Membership Termination Date], MR.MemberID,
       ---Case M.ValMemberTypeID When 1 Then 1 Else 0 End AS UniqueMembershipFlag,
       MS.MembershipID, M.FirstName, M.MiddleName, M.LastName,
       MA.AddressLine1, MA.AddressLine2, MA.City, S.Abbreviation AS State, MA.Zip,
       MPN.HomePhoneNumber, M.EmailAddress,
       Sum(CASE P.Description When 'Enrollment Fee' Then TI.ItemAmount * #PlanRate.PlanRate Else Null End) AS InitFee,
       Sum(CASE P.Description When 'Enrollment Fee' Then TI.ItemAmount Else Null End) AS LocalCurrency_InitFee,
       Sum(CASE P.Description When 'Enrollment Fee' Then TI.ItemAmount * #ToUSDPlanRate.PlanRate Else Null End) AS USD_InitFee,
       Sum(CASE P.Description When 'Initiation Fee Rejoin' Then TI.ItemAmount * #PlanRate.PlanRate Else Null End) AS InitReJoinFee,
       Sum(CASE P.Description When 'Initiation Fee Rejoin' Then TI.ItemAmount Else Null End) AS LocalCurrency_InitReJoinFee,
       Sum(CASE P.Description When 'Initiation Fee Rejoin' Then TI.ItemAmount * #ToUSDPlanRate.PlanRate Else Null End) AS USD_InitReJoinFee,
       P2.Description as [Membership Type], CP.Price * #PlanRate.PlanRate AS [Monthly Dues], CP.Price AS [LocalCurrency_Monthly Dues],
       CP.Price * #ToUSDPlanRate.PlanRate AS [USD_Monthly Dues],
       CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #PlanRate.PlanRate        -- added 9/17/2009 GRB
            ELSE (CP.Price + (CP.Price * CPTR.taxpercentage/100)) * #PlanRate.PlanRate END [Monthly Dues Plus Tax],  -- added 9/17/2009 GRB
       CASE WHEN CPTR.taxpercentage is null THEN CP.Price
            ELSE CP.Price + (CP.Price * CPTR.taxpercentage/100) END [LocalCurrency_Monthly Dues Plus Tax],    
       CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #ToUSDPlanRate.PlanRate
            ELSE (CP.Price + (CP.Price * CPTR.taxpercentage/100)) * #ToUSDPlanRate.PlanRate END [USD_Monthly Dues Plus Tax],
       MSTAT.Description AS [Member Status],
       [Program Status] = Case When MR.TerminationDate is Null Then 'Active' Else 'Terminated' End,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
/***************************************/
       CO.CompanyName, -- ACME-08 11-7-2012
       CO.CorporateCode, -- ACME-08 11-7-2012
       RP.ReimbursementProgramID -- ACME-08 11-7-2012
  INTO #Results
  FROM vReimbursementProgram RP
  JOIN #ProgramIDList PL ON PL.ProgramID = RP.ReimbursementProgramID
  LEFT JOIN vMemberReimbursement MR ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
  LEFT JOIN vReimbursementProgramIdentifierFormat RPIF ON RPIF.ReimbursementProgramIdentifierFormatID = MR.ReimbursementProgramIdentifierFormatID        -- added 9/17/2009 GRB
  LEFT JOIN vMember M ON MR.MemberID = M.MemberID
  LEFT JOIN vMembership MS ON M.MembershipID = MS.MembershipID
  LEFT JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
  LEFT JOIN vClub C ON MS.ClubID = C.ClubID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode AND YEAR(GETDATE())= #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN vValRegion VR ON C.ValRegionID = VR.ValRegionID
  LEFT JOIN vMMSTran MMS ON MS.MembershipID = MMS.MembershipID
  LEFT JOIN vTranItem TI ON MMS.MMSTranID = TI.MMSTranID
  LEFT JOIN vProduct P ON TI.ProductID = P.ProductID
  LEFT JOIN vProduct P2 ON MST.ProductID = P2.ProductID
  LEFT JOIN vClubProduct CP ON MST.ProductID = CP.ProductID AND MS.ClubID = CP.ClubID
  LEFT JOIN #ClubProductTaxRate CPTR ON CPTR.ClubID = CP.ClubID AND CPTR.ProductID = CP.ProductID                                -- added 9/17/2009 GRB
  LEFT JOIN vMembershipAddress MA ON MS.MembershipID = MA.MembershipID
  LEFT JOIN vValState S ON MA.ValStateID = S.ValStateID
  LEFT JOIN vMemberPhoneNumbers MPN ON MS.MembershipID = MPN.MembershipID
  LEFT JOIN vValMembershipStatus MSTAT ON MS.ValMembershipStatusID = MSTAT.ValMembershipStatusID
  LEFT JOIN vCompany CO ON RP.CompanyID = CO.CompanyID --ACME-08 11-7-2012
 GROUP BY RP.ReimbursementProgramName, RPIF.Description, VR.Description, C.ClubName,
          M.JoinDate, MR.EnrollmentDate, MS.ExpirationDate, MR.MemberID, M.ValMemberTypeID,
          MS.MembershipID, MSTAT.Description, M.FirstName, M.MiddleName, M.LastName,
          MA.AddressLine1, MA.AddressLine2, MA.City, S.Abbreviation, MA.Zip,
          MPN.HomePhoneNumber, M.EmailAddress, P2.Description, CP.Price,
         CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #PlanRate.PlanRate        
              ELSE (CP.Price + (CP.Price * CPTR.taxpercentage/100)) * #PlanRate.PlanRate END,                                    
         CASE WHEN CPTR.taxpercentage is null THEN CP.Price
              ELSE CP.Price + (CP.Price * CPTR.taxpercentage/100) END,    
         CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #ToUSDPlanRate.PlanRate
              ELSE (CP.Price + (CP.Price * CPTR.taxpercentage/100)) * #ToUSDPlanRate.PlanRate END,
         M.ActiveFlag, MR.TerminationDate, VCC.CurrencyCode, #PlanRate.PlanRate, #ToUSDPlanRate.PlanRate,
         CO.CompanyName, CO.CorporateCode, RP.ReimbursementProgramID -- ACME-08 11-7-2012
 ORDER BY RP.ReimbursementProgramName, MS.MembershipID, MR.MemberID

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
SELECT #Results.MemberID,
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
  FROM #Results
  JOIN vMemberReimbursement MR
    ON #Results.MemberID = MR.MemberID
   AND (MR.TerminationDate IS NULL OR MR.TerminationDate > GETDATE())
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN vMemberReimbursementProgramIdentifierPart MRPIP
    ON MR.MemberReimbursementID = MRPIP.MemberReimbursementID
  JOIN vReimbursementProgramIdentifierFormatPart RPIFP
    ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
 GROUP BY #Results.MemberID, 
          RP.ReimbursementProgramID, 
          RP.ReimbursementProgramName, 
          MR.MemberReimbursementID
/****************************************************/

SELECT #Results.ReimbursementProgramName, 
       [Reimbursement Program Identifier Desc],
       Region, 
       ClubName,
       JoinDate, 
       EnrollmentDate, 
       [Program Termination Date],
       [Membership Termination Date], 
       #Results.MemberID,
       MembershipID, FirstName, MiddleName, LastName,
       AddressLine1, AddressLine2, City, State, Zip,
       HomePhoneNumber, EmailAddress,
       InitFee,
       LocalCurrency_InitFee,
       USD_InitFee,
       InitReJoinFee,
       LocalCurrency_InitReJoinFee,
       USD_InitReJoinFee,
       [Membership Type], [Monthly Dues], [LocalCurrency_Monthly Dues],
       [USD_Monthly Dues],
       [Monthly Dues Plus Tax],
       [LocalCurrency_Monthly Dues Plus Tax],    
       [USD_Monthly Dues Plus Tax],
       [Member Status],
       [Program Status],
/******  Foreign Currency Stuff  *********/
       LocalCurrencyCode,
       PlanRate,
       ReportingCurrencyCode,
/***************************************/
       CompanyName PartnerProgramCompanyName,
       CorporateCode PartnerProgramCompanyCode,
       #HealthPartnerIDs.Part1FieldName PartnerProgramIDPart1FieldName,
       #HealthPartnerIDs.Part1Value PartnerProgramIDPart1Value,
       #HealthPartnerIDs.Part2FieldName PartnerProgramIDPart2FieldName,
       #HealthPartnerIDs.Part2Value PartnerProgramIDPart2Value,
       #HealthPartnerIDs.Part3FieldName PartnerProgramIDPart3FieldName,
       #HealthPartnerIDs.Part3Value PartnerProgramIDPart3Value
  FROM #Results
  LEFT JOIN #HealthPartnerIDs
    ON #Results.MemberID = #HealthPartnerIDs.MemberID
   AND #Results.ReimbursementProgramID = #HealthPartnerIDs.ReimbursementProgramID


DROP TABLE #ProgramIDList
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
