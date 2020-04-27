
-- THIS PROCEDURE WILL POPULATE THE MemberReimbursementHistory TABLE WITH ALL MEDICA ENROLLED MEMBERS 
 -- THEIR CLUB USAGE AND MEDICA REIMBURSEMENT ELIGIBILITY.
 -- THE INPUT PARAMETER @UsageFirstOfMonth IS THE FIRST DAY OF THE MONTH FOR WHICH REIMBURSEMENTS WILL BE PROCESSED.
CREATE Procedure [dbo].[mmsPrepareMedicaExportData]
AS
BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON

  DECLARE @NewMemberReimbursementHistoryID INT
  DECLARE @Count INT
  DECLARE @Today DATETIME
  DECLARE @UsageFirstOfMonth DATETIME


   --GET TODAY'S DATE
  SET @ToDay = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 101), 101)
   --GET FIRST OF LAST MONTH
  SET @UsageFirstOfMonth = CONVERT(DATETIME, CONVERT(VARCHAR, MONTH(DATEADD(mm, -1, @ToDay))) + '/01/' + CONVERT(VARCHAR, YEAR(DATEADD(mm, -1, @ToDay))), 101)

   -- CREATE AND POPULATE A TEMP TABLE THAT HOLDS TAX PERCENTAGE INFORMATION FOR 
   -- CALCULATING THE MONTHLY DUES.
  CREATE TABLE #TaxPercentage(ClubID INT, ProductID INT, TaxPercentage DECIMAL(4,2))
  INSERT INTO #TaxPercentage(ClubID, ProductID, TaxPercentage)
  SELECT CPTR.ClubID, CPTR.ProductID, SUM(TR.TaxPercentage)
    FROM vClubProductTaxRate CPTR JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
   GROUP BY ClubID, ProductID

  CREATE TABLE #MemberReimbursementHistory(MemberReimbursementHistoryID INT IDENTITY(1,1), MembershipID INT, MemberID INT,
                                           ReimbursementProgramID INT, UsageFirstOfMonth DATETIME, EnrollmentDate DATETIME,
                                           MonthlyDues NUMERIC(8,4), EstimatedReimbursementAmount NUMERIC(8,4),
                                           ActualReimbursementAmount NUMERIC(8,4), ClubID INT, ReimbursementErrorCodeID INT,
                                           ReimbursementQualifiedFlag BIT, QualifiedClubUtilization INT, MedicaNumber VARCHAR(16))

   -- POPULATE THE #MemberReimbursementHistory TABLE WITH ALL MEDICA ENROLLED MEMBERS THAT ARE ELIGIBLE
   -- FOR THE REPORTING MONTH AND ARE OVER 18 YEARS OF AGE.
   -- IF DOB IS NOT AVAILABLE FOR A MEMBER THEN CONSIDER THAT HE IS OVER 18 YEARS.
  INSERT INTO #MemberReimbursementHistory(MembershipID, MemberID, ReimbursementProgramID, UsageFirstOfMonth,
                                           EnrollmentDate, MonthlyDues, EstimatedReimbursementAmount, 
                                           ActualReimbursementAmount, ClubID, ReimbursementErrorCodeID,
                                           ReimbursementQualifiedFlag, QualifiedClubUtilization, MedicaNumber)
  SELECT DISTINCT MS.MembershipID, MR.MemberID, MR.ReimbursementProgramID, @UsageFirstOfMonth, MR.EnrollmentDate,
         CAST(CP.Price + ((ISNULL(TP.TaxPercentage, 0) / 100) * CP.Price) AS MONEY), VMP.ReimbursementAmount, NULL,
         MS.ClubID, NULL, 0, 0, NULL
    FROM vMemberReimbursement MR JOIN vMember M ON MR.MemberID = M.MemberID
                                 JOIN vMembership MS ON M.MembershipID = MS.MembershipID
                                 JOIN vClubProduct CP ON MS.ClubID = CP.ClubID
                                                     AND MS.MembershipTypeID = CP.ProductID
                                 LEFT JOIN #TaxPercentage TP ON CP.ClubID = TP.ClubID
                                                            AND CP.ProductID = TP.ProductID
                                 JOIN (SELECT MR.MemberID, MRPIP.PartValue
                                         FROM vMemberReimbursement MR JOIN vMemberReimbursementProgramIdentifierPart MRPIP
                                                                        ON MR.MemberReimbursementID = MRPIP.MemberReimbursementID
                                        WHERE MRPIP.ReimbursementProgramIdentifierFormatPartID IN (4,7,9)
                                          AND (MR.TerminationDate IS NULL OR MR.TerminationDate >= @UsageFirstOfMonth)
                                        GROUP BY MR.MemberID, MRPIP.PartValue, MR.MemberReimbursementID
                                       HAVING MR.MemberReimbursementID = MAX(MR.MemberReimbursementID)) T1 ON MR.MemberID = T1.MemberID
                                 JOIN vMedicaCompany MC ON T1.PartValue = MC.MedicaCompanyCode
                                 JOIN vValMedicaProgram VMP ON MC.ValMedicaProgramID = VMP.ValMedicaProgramID
   WHERE (MR.TerminationDate IS NULL OR MR.TerminationDate > @UsageFirstOfMonth)
     AND MR.ReimbursementProgramID = 2
     AND MR.ReimbursementProgramIdentifierFormatID IN (2,3,4)
     AND ISNULL(M.DOB, 'JAN 01 1960') < DATEADD(YEAR, -18, @UsageFirstOfMonth)
     AND MR.EnrollmentDate < DATEADD(MONTH, 1, @UsageFirstOfMonth)
     AND (MS.ExpirationDate >= DATEADD(m, -1, @UsageFirstOfMonth) OR MS.ExpirationDate IS NULL)
     AND MC.StartDate <= @UsageFirstOfMonth 
     AND MC.EndDate >= DATEADD(MONTH, 1, @UsageFirstOfMonth)
     AND ValMemberTypeID <> 4

   -- GET ALL MEDICA ENROLLED MEMBERUSAGE FOR THE REPORTING MONTH
   -- WITH A MAX OF 2 USES PER DAY.
  SELECT MU.MemberID, DAY(MU.UsageDateTime) UsageDay, 
         CASE
           WHEN COUNT(*) > 2 THEN 2
         ELSE COUNT(*)
         END CheckInCount
    INTO #T1
    FROM vMemberUsage MU JOIN #MemberReimbursementHistory MRH ON MU.MemberID = MRH.MemberID
   WHERE MU.UsageDateTime >= @UsageFirstOfMonth AND MU.UsageDateTime < DATEADD(MONTH, 1, @UsageFirstOfMonth)
   GROUP BY MU.MemberID, DAY(MU.UsageDateTime)

   -- GET ALL MEDICA ENROLLED MEMBERS AND THEIR TOTAL CLUB USAGE FOR THE MONTH.
  SELECT MemberID, SUM(CheckInCount) TotalCheckIns
    INTO #T2
    FROM #T1
   GROUP BY MemberID

   -- UPDATE #MemberReimbursementHistory TABLE WITH REIMBURSEMENT QUALIFIED DATA.
  UPDATE #MemberReimbursementHistory
     SET QualifiedClubUtilization = TotalCheckIns
    FROM #MemberReimbursementHistory MRH JOIN #T2 T ON MRH.MemberID = T.MemberID

   -- SELECT THE MEMBERS THAT HAVE 8 CHECKINS IN A MONTH INTO A TEMP TABLE TO IDENTIFY THE REIMBURSEMENT
   -- QUALIFIED MEMBERS.
  SELECT * 
    INTO #T3
    FROM #MemberReimbursementHistory
   WHERE QualifiedClubUtilization >= 8

   --IF MORE THAN ONE MEMBER IN A MEMBERSHIP REMAIN, THEN LEAVE THE MEMBER WITH THE HIGHEST USAGE
   DELETE #T3
   FROM #T3 T1 JOIN(SELECT MembershipID,MAX(QualifiedClubUtilization) QualifiedClubUtilization
                    FROM #T3
                    GROUP BY MembershipID) T2
               ON T1.MembershipID = T2.MembershipID 
              AND T1.QualifiedClubUtilization <> T2.QualifiedClubUtilization

   -- IF MORE THAN ONE MEMBER IN A MEMBERSHIP REMAIN, THEN FILTER MEMBERS BY ValMemberTypeID (I.E. PRIMARY, 
   -- PARTNER, AND SECONDARY).
  DELETE 
    FROM #T3 
    FROM #T3 T1 JOIN vMember M ON T1.MemberID = M.MemberID
                JOIN(SELECT T3.MembershipID, MIN(M.ValMemberTypeID) MemberType
                       FROM #T3 T3 JOIN vMember M ON T3.MemberID = M.MemberID
                      GROUP BY T3.MembershipID
                     HAVING COUNT(*) > 1) T2 ON M.MembershipID = T2.MembershipID 
                                            AND M.ValMemberTypeID <> T2.MemberType

   -- IF MORE THAN ONE MEMBER IN A MEMBERSHIP REMAIN, THEN FILTER MEMBERS BY DATE OF BIRTH.
  DELETE
    FROM #T3
    FROM #T3 T1 JOIN vMember M ON T1.MemberID = M.MemberID
                JOIN (SELECT T3.MembershipID, MIN(M.DOB) DateOfBirth
                        FROM #T3 T3 JOIN vMember M ON T3.MemberID = M.MemberID
                       GROUP BY T3.MembershipID
                      HAVING COUNT(*) > 1) T2 ON M.MembershipID = T2.MembershipID
                                             AND M.DOB <> T2.DateOfBirth
  
   -- IF MORE THAN ONE MEMBER IN A MEMBERSHIP REMAIN, THEN FILTER MEMBERS BY MEMBERID
  DELETE
    FROM #T3
    FROM #T3 T1 JOIN vMember M ON T1.MemberID = M.MemberID
                JOIN (SELECT T3.MembershipID, MIN(M.MemberID) MinMemberID
                        FROM #T3 T3 JOIN vMember M ON T3.MemberID = M.MemberID
                       GROUP BY T3.MembershipID
                      HAVING COUNT(*) > 1) T2 ON M.MembershipID = T2.MembershipID
                                             AND M.MemberID <> T2.MinMemberID

   -- SET THE ReimbursementQualifiedFlag TO TRUE FOR THE REMAINING MEMBERS.
  UPDATE #MemberReimbursementHistory
     SET ReimbursementQualifiedFlag = 1
    FROM #MemberReimbursementHistory MRH JOIN #T3 T ON MRH.MemberID = T.MemberID

   -- DELETE ANY OLD RECORDS FOR MEMBERS WITH MORE THAN 1 RECORD.
  DELETE
    FROM #MemberReimbursementHistory
    FROM #MemberReimbursementHistory MRH JOIN (SELECT MemberID, MAX(EnrollmentDate) EnrollmentDate
                                                 FROM #MemberReimbursementHistory
                                                GROUP BY MemberID
                                               HAVING COUNT(*) > 1) T1 ON MRH.MemberID = T1.MemberID
                                                                      AND MRH.EnrollmentDate <> T1.EnrollmentDate

   -- GET THE NEXT MemberReimbursementHistoryID AND UPDATE THE SQUENCE TABLE.

  SELECT @NewMemberReimbursementHistoryID =ISNULL(MAX(MemberReimbursementHistoryID),0)
   FROM vMemberReimbursementHistory

   -- INSERT THE NEW MemberReimbursementHisory RECORDS.
  INSERT INTO tmpMemberReimbursementHistory(MemberReimbursementHistoryID,MembershipID, MemberID, 
                                            ReimbursementProgramID, UsageFirstOfMonth, EnrollmentDate, 
                                            MonthlyDues, EstimatedReimbursementAmount, ActualReimbursementAmount,
                                            ClubID, ReimbursementErrorCodeID, ReimbursementQualifiedFlag,
                                            QualifiedClubUtilization)
  SELECT @NewMemberReimbursementHistoryID + MemberReimbursementHistoryID, MembershipID, MemberID,
         ReimbursementProgramID, UsageFirstOfMonth, EnrollmentDate, MonthlyDues,
         CASE ReimbursementQualifiedFlag
           WHEN 1 THEN EstimatedReimbursementAmount
         ELSE 0.00
         END,
         ActualReimbursementAmount, ClubID, ReimbursementErrorCodeID, ReimbursementQualifiedFlag,
         QualifiedClubUtilization
    FROM #MemberReimbursementHistory

   -- DROP ALL TEMP TABLES.
  DROP TABLE #T1
  DROP TABLE #T2
  DROP TABLE #T3
  DROP TABLE #MemberReimbursementHistory
  DROP TABLE #TaxPercentage


END
