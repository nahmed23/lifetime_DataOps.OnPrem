





CREATE PROC [dbo].[mmsCorpUser_Memberusage] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @CompanyList VARCHAR(8000),
  @MemberType VARCHAR(50),
  @PURFlag INT,
  @CompanyListType VARCHAR(25))

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @HeaderDateRange Varchar(110)
SET @HeaderDateRange = Replace(Substring(convert(varchar,@StartDate,100),1,6)+', '+Substring(convert(varchar,@StartDate,100),8,4),'  ',' ')
                       + ' through ' + 
                       Replace(Substring(convert(varchar,@EndDate,100),1,6)+', '+Substring(convert(varchar,@EndDate,100),8,4),'  ',' ')

CREATE TABLE #tmpList (StringField VARCHAR(50))
  
CREATE TABLE #MemberType (MemberDescription VARCHAR(50))
EXEC procParseStringList @MemberType
INSERT INTO #MemberType (MemberDescription) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList
  
CREATE TABLE #Company (CompanyCode VARCHAR(50))
IF @CompanyList <> 'All'
  BEGIN
    EXEC procParseStringList @CompanyList
    INSERT INTO #Company (CompanyCode) SELECT StringField FROM #tmpList
  END
ELSE
  BEGIN
    INSERT INTO #Company VALUES('All') 
  END

SELECT Membership.MembershipID,
       Membership.ClubID,
       Membership.CompanyID,
       Membership.CancellationRequestDate,
       Membership.ExpirationDate,
       Membership.MembershipTypeID,
       Membership.ValMembershipStatusID,
       Membership.QualifiedSalesPromotionID,
       ValMembershipStatus.Description MembershipStatusDescription,
       Membership.ClubID OriginalMembershipClubID,
       Membership.JrmemberDuesproductID       
  INTO #Membership
  FROM vMembership Membership WITH (NOLOCK)
  JOIN vValMembershipStatus ValMembershipStatus
    ON Membership.ValMembershipStatusID = ValMembershipStatus.ValMembershipStatusID
 WHERE (Membership.ExpirationDate IS NULL OR Membership.ExpirationDate >= @StartDate)
   AND ValMembershipStatus.Description IN ('Active', 'Pending Termination','Terminated') 
 
CREATE INDEX IX_MembershipID ON #Membership(MembershipID)
CREATE INDEX IX_ClubID ON #Membership(ClubID)

SELECT CPPT.ClubID, 
       CPPT.ProductID, 
       CPPT.Price, 
       SUM(CAST((ISNULL(TaxPercentage,0)/100) * Price AS Decimal(12,2))) TaxAmount
  INTO #ClubProductPriceTax
  FROM vClubProductPriceTax CPPT
  JOIN vProduct P 
    ON CPPT.ProductID = P.ProductID
 WHERE P.DepartmentID = 1
 GROUP BY CPPT.ClubID, CPPT.ProductID, CPPT.Price
 
 
 SELECT MS.MembershipID, 
       COUNT(M.MemberID) NumberOfJuniors,
       SUM(CASE When ((M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag Is Null)
                      AND 
                       (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag Is Null )
                      AND 
                       (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag Is Null))
                THEN PTP.Price
                ELSE 0
                END ) JrMembershipDues,
       SUM(CASE When ((M.AssessJrMemberDuesFlag = 1 or M.AssessJrMemberDuesFlag Is Null)
                      AND 
                       (C.AssessJrMemberDuesFlag = 1 or C.AssessJrMemberDuesFlag Is Null )
                      AND 
                       (MT.AssessJrMemberDuesFlag = 1 or MT.AssessJrMemberDuesFlag Is Null))
                 THEN CPPT.TaxAmount
                 ELSE 0
                 END) JrMembershipDuesTax
  INTO #JuniorMemberInfo
  FROM #Membership MS
  Join vMembershipProductTier MPT
    ON MS.MembershipID = MPT.MembershipID
  Join vProductTier  PT
    ON MPT.ProductTierID = PT.ProductTierID  
  Join vProductTierPrice PTP
    ON PT.ProductTierID = PTP.ProductTierID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN vValMembershipTypeGroup VMTG
    ON PTP.ValMembershipTypeGroupID= VMTG.ValMembershipTypeGroupID
    AND MT.ValMembershipTypeGroupID = VMTG.ValMembershipTypeGroupID
  Join vClub C
    ON MS.ClubID = C.ClubID
  JOIN vMember M
    ON MS.MembershipID = M.MembershipID
  LEFT JOIN #ClubProductPriceTax CPPT
    ON MS.OriginalMembershipClubID = CPPT.ClubID
   AND MS.JrMemberDuesProductID = CPPT.ProductID
 WHERE M.ValMemberTypeID = 4
   AND M.ActiveFlag = 1
   AND PT.ValProductTierTypeID = 1
 GROUP BY MS.MembershipID


SELECT MS.CancellationRequestDate, 
       CO.CompanyName,
       VR.Description AS RegionDescription, 
       C.ClubName,
       M.MemberID, 
       M.FirstName, 
       M.LastName, 
       M.JoinDate as JoinDate_Sort,
       Replace(Substring(convert(varchar,M.JoinDate,100),1,6)+', '+Substring(convert(varchar,M.JoinDate,100),8,4),'  ',' ') JoinDate,
       MS.MembershipStatusDescription, 
       CO.AccountRepInitials, 
       MS.ExpirationDate, 
       CO.CompanyID, 
       P.Description AS ProductDescription, 
       VMT.Description AS MemberTypeDescription, 
       MS.MembershipID, 
       IsNull(MU.UsageDateTime,'Jan 1,1900') AS UsageDateTime,
       NULL PromotionName, 
       CPPT1.Price MembershipDuesPrice,
       ISNULL(#JuniorMemberInfo.JrMembershipDues,0) JrMembershipDues,
       CPPT1.TaxAmount + ISNULL(#JuniorMemberInfo.JrMembershipDuesTax,0) TaxAmount,
       Substring(Convert(Varchar,DOB,110),1,5) BirthDate,
       UC.ClubName AS CheckInClub,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       VS.Abbreviation as StateAbbr,
       MA.Zip as ZipCode,
       CASE WHEN DateDiff(day,M.JoinDate,@EndDate) < 8
            THEN 'Y'
            ELSE 'N'
            END MemberJoinedThisWeek
  INTO #Results
  FROM dbo.vClub C
  JOIN dbo.#Membership MS
    ON MS.ClubID=C.ClubID
  JOIN dbo.vMember M
    ON M.MembershipID=MS.MembershipID
  JOIN dbo.vValRegion VR
    ON VR.ValRegionID=C.ValRegionID
  JOIN dbo.vCompany CO
    ON MS.CompanyID=CO.CompanyID
  JOIN #Company tC
    ON (CO.CorporateCode = tC.CompanyCode
    OR tC.CompanyCode = 'All')
    AND @CompanyListType = 'Membership Company'
  JOIN dbo.vMembershipType MST
    ON MS.MembershipTypeID=MST.MembershipTypeID
  JOIN dbo.vProduct P
    ON P.ProductID=MST.ProductID
  JOIN dbo.vValMemberType VMT
    ON M.ValMemberTypeID=VMT.ValMemberTypeID
  JOIN vMembershipAddress MA
    ON MS.MembershipID = MA.MembershipID
  JOIN vValState VS
    ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vMemberUsage MU
    ON MU.MemberID = M.MemberID 
   AND MU.UsageDateTime BETWEEN @StartDate AND @EndDate
  LEFT JOIN vClub UC
    ON MU.ClubID = UC.ClubID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  LEFT JOIN #ClubProductPriceTax CPPT1
    ON MT.ProductID = CPPT1.ProductID
   AND MS.OriginalMembershipClubID = CPPT1.ClubID
  LEFT JOIN #JuniorMemberInfo
    ON MS.MembershipID = #JuniorMemberInfo.MembershipID
 WHERE VMT.Description IN (SELECT MemberDescription FROM #MemberType)
   AND M.ActiveFlag = 1
   AND (CO.PrintUsageReportFlag = 1 OR CO.PrintUsageReportFlag = @PURFlag)

UNION

SELECT MS.CancellationRequestDate, 
       NULL CompanyName, 
       VR.Description AS RegionDescription, 
       C.ClubName,
       M.MemberID, 
       M.FirstName, 
       M.LastName, 
       M.JoinDate as JoinDate_Sort,
       Replace(Substring(convert(varchar,M.JoinDate,100),1,6)+', '+Substring(convert(varchar,M.JoinDate,100),8,4),'  ',' ') JoinDate,
       MS.MembershipStatusDescription, 
       NULL AccountRepInitials, 
       MS.ExpirationDate, 
       NULL CompanyID, 
       P.Description AS ProductDescription, 
       VMT.Description AS MemberTypeDescription, 
       MS.MembershipID, 
       IsNull(MU.UsageDateTime,'Jan 1,1900') AS UsageDateTime,
       QSP.PromotionName, 
       CPPT1.Price MembershipDuesPrice,
       ISNULL(#JuniorMemberInfo.JrMembershipDues,0) JrMembershipDues,
       --(ISNULL(CPPT1.Price,0) * ISNULL(CPPT1.TaxPercentage/100,0)) + ISNULL(#JuniorMemberInfo.JrMembershipDuesTax,0) TaxAmount,
       CPPT1.TaxAmount + ISNULL(#JuniorMemberInfo.JrMembershipDuesTax,0) TaxAmount,
       Substring(Convert(Varchar,DOB,110),1,5) BirthDate,
       UC.ClubName AS CheckInClub,
       MA.AddressLine1,
       MA.AddressLine2,
       MA.City,
       VS.Abbreviation as StateAbbr,
       MA.Zip as ZipCode,
       CASE WHEN DateDiff(day,M.JoinDate,@EndDate) < 8
            THEN 'Y'
            ELSE 'N'
            END MemberJoinedThisWeek
  FROM dbo.vClub C
  JOIN dbo.#Membership MS
    ON MS.ClubID=C.ClubID
  JOIN dbo.vMember M
    ON M.MembershipID=MS.MembershipID
  JOIN dbo.vValRegion VR
    ON VR.ValRegionID=C.ValRegionID
  JOIN dbo.vMembershipType MST
    ON MS.MembershipTypeID=MST.MembershipTypeID
  JOIN dbo.vProduct P
    ON P.ProductID=MST.ProductID
  JOIN dbo.vValMemberType VMT
    ON M.ValMemberTypeID=VMT.ValMemberTypeID
  JOIN vMembershipAddress MA
    ON MS.MembershipID = MA.MembershipID
  JOIN vValState VS
    ON MA.ValStateID = VS.ValStateID
  LEFT JOIN dbo.vMemberUsage MU
    ON MU.memberid = M.memberid
   AND MU.UsageDateTime BETWEEN @StartDate AND @EndDate
  LEFT JOIN vClub UC
    ON MU.ClubID = UC.ClubID
  JOIN vQualifiedSalesPromotion QSP
    ON MS.QualifiedSalesPromotionID = QSP.QualifiedSalesPromotionID
  JOIN vMembershipType MT
    ON MS.MembershipTypeID = MT.MembershipTypeID
  JOIN #Company tC
    ON QSP.SalesPromotionID = tC.CompanyCode
    --OR tC.CompanyCode = 'All')
    AND @CompanyListType = 'Qualified Sales Promotion'
  LEFT JOIN #ClubProductPriceTax CPPT1
    ON MT.ProductID = CPPT1.ProductID
   AND MS.OriginalMembershipClubID = CPPT1.ClubID
  LEFT JOIN #JuniorMemberInfo
    ON MS.MembershipID = #JuniorMemberInfo.MembershipID
 WHERE VMT.Description IN (SELECT MemberDescription FROM #MemberType)
   AND M.ActiveFlag = 1
   
   
   CREATE TABLE #LastPartnerProgamVersionInPeriod (
   MemberID INT,
   ReimbursementProgramID INT,
   ReimbursementProgramName VARCHAR(50),
   MemberReimbursementID INT
   )
   
   INSERT INTO #LastPartnerProgamVersionInPeriod
   SELECT MR.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       MAX(MR.MemberReimbursementID)
  FROM #Results
  JOIN vMemberReimbursement MR
    ON #Results.MemberID = MR.MemberID
   AND (MR.EnrollmentDate <= @EndDate)
   AND (MR.TerminationDate IS NULL OR MR.TerminationDate > @StartDate)
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
 GROUP BY MR.MemberID, 
          RP.ReimbursementProgramID, 
          RP.ReimbursementProgramName 



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
Part3Value VARCHAR(100),
ProgramTerminationDate Datetime)



INSERT INTO #HealthPartnerIDs
SELECT #LastPartnerProgamVersionInPeriod.MemberID,
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
       MAX(CASE WHEN RPIFP.FieldSequence = 3 THEN MRPIP.PartValue ELSE '' END) Part3Value,
       MR.TerminationDate AS  ProgramTerminationDate
  FROM #LastPartnerProgamVersionInPeriod
  JOIN vMemberReimbursement MR
    ON #LastPartnerProgamVersionInPeriod.MemberReimbursementID = MR.MemberReimbursementID
  JOIN vReimbursementProgram RP
    ON MR.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN vCompany CO              ------------------- added join 10/24/2012  QC2317  SRM
    ON RP.CompanyID = CO.CompanyID
  JOIN vMemberReimbursementProgramIdentifierPart MRPIP
    ON MR.MemberReimbursementID = MRPIP.MemberReimbursementID
  JOIN vReimbursementProgramIdentifierFormatPart RPIFP
    ON MRPIP.ReimbursementProgramIdentifierFormatPartID = RPIFP.ReimbursementProgramIdentifierFormatPartID
Group By #LastPartnerProgamVersionInPeriod.MemberID,
       RP.ReimbursementProgramID,
       RP.ReimbursementProgramName,
       MR.TerminationDate,
       MR.MemberReimbursementID


SELECT DISTINCT MemberID
  INTO #ResultsDistinctMemberIDs
  FROM #Results

DECLARE @FirstOfNextMonth DATETIME
DECLARE @SecondOfNextMonth DATETIME
DECLARE @SecondOfCurrentMonth DATETIME

SET @FirstOfNextMonth = DATEADD(MM,DATEDIFF(M,0,@EndDate)+1,0)
SET @SecondOfNextMonth = @FirstOfNextMonth + 1
SET @SecondOfCurrentMonth = DATEADD(d,-(DATEPART(d,@StartDate)-2),@StartDate)

CREATE TABLE #DuesCredits (
MemberID INT, 
CalculatedDuesCredit DECIMAL(12,2), 
PartnerSpecificDuesCredit DECIMAL(12,2),
ReimbursementProgramNames VARCHAR(8000))

INSERT INTO #DuesCredits           
SELECT DISTINCT OuterMMSTran.MemberID,
                SUM(CASE WHEN ReasonCodeID = 211 THEN (POSAmount + TranAmount) ELSE 0 END) CalculatedDuesCredit,
                SUM(CASE WHEN ReasonCodeID = 210 THEN (POSAmount + TranAmount) ELSE 0 END) PartnerSpecificDuesCredit,
                STUFF((SELECT ' $'+Cast(ABS(POSAmount + TranAmount) as varchar) + ' - ' + ReimbursementProgram.ReimbursementProgramName
                         FROM vMMSTran InnerMMSTran
                         JOIN vReimbursementProgram ReimbursementProgram
                           ON InnerMMSTran.ReimbursementProgramID = ReimbursementProgram.ReimbursementProgramID
                        WHERE ReasonCodeID in (211,210) ----"ACMEPartSubs - Partner Dues Reimbursement" & "ACMECalcSubs - Partner Program Dues Reimbursement"
                          AND PostDateTime >= @SecondOfCurrentMonth
                          AND PostDateTime < @SecondOfNextMonth
                          AND OuterMMSTran.MemberID = InnerMMSTran.MemberID
                        ORDER BY MemberID
                          FOR XML PATH(''),ROOT('ReimbursementProgramNames'),type).value('/ReimbursementProgramNames[1]','varchar(8000)'),1,1,'') ReimbursementProgramNames
  FROM #ResultsDistinctMemberIDs
  JOIN vMMSTran OuterMMSTran
    ON #ResultsDistinctMemberIDs.MemberID = OuterMMSTran.MemberID
 WHERE ReasonCodeID in (211,210)
   AND PostDateTime >= @SecondOfCurrentMonth
   AND PostDateTime < @SecondOfNextMonth
GROUP BY OuterMMSTran.MemberID

SELECT #Results.CancellationRequestDate,
       #Results.CompanyName,
       #Results.RegionDescription,
       #Results.ClubName,
       #Results.MemberID,
       #Results.FirstName,
       #Results.LastName,
       #Results.JoinDate_Sort,
       #Results.JoinDate,
       #Results.MembershipStatusDescription,
       #Results.AccountRepInitials,
       #Results.ExpirationDate AS MembershipExpirationDate,
       #Results.CompanyID,
       #Results.ProductDescription,
       #Results.MemberTypeDescription,
       #Results.MembershipID,
       #Results.UsageDateTime,
       #Results.PromotionName,
       #Results.MembershipDuesPrice,
       #Results.JrMembershipDues,
       #Results.TaxAmount,
       #Results.BirthDate,
       #HealthPartnerIDs.ReimbursementProgramName,
       #HealthPartnerIDs.HealthPartnerID,
       #HealthPartnerIDs.Part1FieldName,
       #HealthPartnerIDs.Part1Value,
       #HealthPartnerIDs.Part2FieldName,
       #HealthPartnerIDs.Part2Value,
       #HealthPartnerIDs.Part3FieldName,
       #HealthPartnerIDs.Part3Value,
       ABS(#DuesCredits.PartnerSpecificDuesCredit) AS PartnerSpecificDuesCredit,
       ABS(#DuesCredits.CalculatedDuesCredit)AS CalculatedDuesCredit,
       #DuesCredits.ReimbursementProgramNames AS DuesCredit_ReimbursmentProgramNames,
       @HeaderDateRange HeaderDateRange,
       #HealthPartnerIDs.ProgramTerminationDate,
       #Results.CheckInClub,
       #Results.AddressLine1,
       #Results.AddressLine2,
       #Results.City,
       #Results.StateAbbr,
       #Results.ZipCode, 
       #Results.MemberJoinedThisWeek
  FROM #Results
  LEFT JOIN #HealthPartnerIDs
    ON #Results.MemberID = #HealthPartnerIDs.MemberID
  LEFT JOIN #DuesCredits
    ON #Results.MemberID = #DuesCredits.MemberID


DROP TABLE #Company
DROP TABLE #MemberType
DROP TABLE #tmpList
DROP TABLE #Results
DROP TABLE #ResultsDistinctMemberIDs
DROP TABLE #HealthPartnerIDs


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END



