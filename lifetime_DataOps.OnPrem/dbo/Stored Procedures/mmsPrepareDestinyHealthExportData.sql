





-- THIS PROCEDURE WILL POPULATE THE MemberReimbursementHistory TABLE WITH ALL DestinyHealth ENROLLED MEMBERS 
 -- AND THEIR CLUB USAGE.
 -- THE INPUT PARAMETER @UsageFirstOfMonth IS THE FIRST DAY OF THE MONTH FOR WHICH REIMBURSEMENTS WILL BE PROCESSED.
CREATE Procedure [dbo].[mmsPrepareDestinyHealthExportData]
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

  CREATE TABLE #TaxPercentage(ClubID INT, ProductID INT, TaxPercentage DECIMAL(4,2))
  INSERT INTO #TaxPercentage(ClubID, ProductID, TaxPercentage)
  SELECT CPTR.ClubID, CPTR.ProductID, SUM(TR.TaxPercentage)
    FROM vClubProductTaxRate CPTR JOIN vTaxRate TR ON CPTR.TaxRateID = TR.TaxRateID
   GROUP BY ClubID, ProductID

  CREATE TABLE #MemberReimbursementHistory(MemberReimbursementHistoryID INT IDENTITY(1,1), MembershipID INT, MemberID INT,
                                           ReimbursementProgramID INT, UsageFirstOfMonth DATETIME, EnrollmentDate DATETIME,
                                           MonthlyDues NUMERIC(8,4), EstimatedReimbursementAmount NUMERIC(8,4),
                                           ActualReimbursementAmount NUMERIC(8,4), ClubID INT, ReimbursementErrorCodeID INT,
                                           ReimbursementQualifiedFlag BIT, QualifiedClubUtilization INT)

   -- POPULATE THE #MemberReimbursementHistory TABLE WITH ALL DestinyHealth ENROLLED MEMBERS THAT ARE ELIGIBLE
   -- FOR THE REPORTING MONTH.
  INSERT INTO #MemberReimbursementHistory(MembershipID, MemberID, ReimbursementProgramID, UsageFirstOfMonth,
                                           EnrollmentDate, MonthlyDues, EstimatedReimbursementAmount, 
                                           ActualReimbursementAmount, ClubID, ReimbursementErrorCodeID,
                                           ReimbursementQualifiedFlag, QualifiedClubUtilization)
  SELECT DISTINCT MS.MembershipID, MR.MemberID, MR.ReimbursementProgramID, @UsageFirstOfMonth, MR.EnrollmentDate,
         CAST(CP.Price + ((ISNULL(TP.TaxPercentage, 0) / 100) * CP.Price) AS MONEY), 0, NULL,
         MS.ClubID, NULL, NULL, 0
    FROM vMemberReimbursement MR JOIN vMember M ON MR.MemberID = M.MemberID
                                 JOIN vMembership MS ON M.MembershipID = MS.MembershipID
                                 JOIN vClubProduct CP ON MS.ClubID = CP.ClubID
                                                     AND MS.MembershipTypeID = CP.ProductID
                                 LEFT JOIN #TaxPercentage TP ON CP.ClubID = TP.ClubID
                                                            AND CP.ProductID = TP.ProductID
   WHERE (MR.TerminationDate IS NULL OR MR.TerminationDate > @UsageFirstOfMonth)
     AND (MS.ExpirationDate >= DATEADD(m, -1, @UsageFirstOfMonth) OR MS.ExpirationDate IS NULL)
     AND (MR.ReimbursementProgramID = 638
	      OR
		  (MR.ReimbursementProgramID = 3
		   AND
		   MR.ReimbursementProgramIdentifierFormatID = 48
		  )
		  )
     AND MR.EnrollmentDate < DATEADD(m, 1, @UsageFirstOfMonth)
   
   UNION
     SELECT DISTINCT MS.MembershipID, MR.MemberID, MR.ReimbursementProgramID, @UsageFirstOfMonth, MR.EnrollmentDate,
         CAST(CP.Price + ((ISNULL(TP.TaxPercentage, 0) / 100) * CP.Price) AS MONEY), 0, NULL,
         MS.ClubID, NULL, NULL, 0
    FROM vMemberReimbursement MR JOIN vMember M ON MR.MemberID = M.MemberID
                                 JOIN vMembership MS ON M.MembershipID = MS.MembershipID
                                 JOIN vClubProduct CP ON MS.ClubID = CP.ClubID
                                                     AND MS.MembershipTypeID = CP.ProductID
                                 LEFT JOIN #TaxPercentage TP ON CP.ClubID = TP.ClubID
                                                            AND CP.ProductID = TP.ProductID
   WHERE (MR.TerminationDate IS NULL OR MR.TerminationDate > @UsageFirstOfMonth)
     AND (MS.ExpirationDate >= DATEADD(m, -1, @UsageFirstOfMonth) OR MS.ExpirationDate IS NULL)
     AND MR.ReimbursementProgramID = 3
	 AND MR.ReimbursementProgramIdentifierFormatID = 4
     AND MR.EnrollmentDate < DATEADD(m, 1, @UsageFirstOfMonth)
	 AND MR.MemberID NOT IN(SELECT MemberID FROM vMemberReimbursement WHERE ReimbursementProgramID = 638)

   -- GET THE MEMBER USAGE FOR THE ACTIVE DestinyHealth MEMBERS, MAX OF ONE USE PER DAY.
    SELECT MRH.MemberID, MU.UsageDateTime
      INTO #tmpMemberUsage
      FROM #MemberReimbursementHistory MRH JOIN vMemberUsage MU ON MRH.MemberID = MU.MemberID
     WHERE MU.UsageDateTime >= @UsageFirstOfMonth
       AND MU.UsageDateTime < DATEADD(m, 1, @UsageFirstOfMonth)

    CREATE TABLE #TotalMemberUsage(MemberID INT,UsageDateTime DATETIME)

    WHILE (SELECT COUNT(*) FROM #tmpMemberUsage) > 0
    BEGIN
         INSERT INTO #TotalMemberUsage
         SELECT MemberID,MIN(UsageDateTime) UsageDateTime
         FROM #tmpMemberUsage 
         GROUP BY MemberID

        DELETE #tmpMemberUsage FROM #tmpMemberUsage A JOIN #TotalMemberUsage B ON A.MemberID = B.MemberID AND A.UsageDateTime <= DATEADD(MI,5,B.UsageDateTime)
    END

    SELECT MemberID, COUNT(UsageDateTime) AS QualifiedClubUtilization
    INTO #MemberUsage
    FROM #TotalMemberUsage
    GROUP BY MemberID

  UPDATE #MemberReimbursementHistory
     SET QualifiedClubUtilization = MU.QualifiedClubUtilization
    FROM #MemberReimbursementHistory MRH JOIN #MemberUsage MU ON MRH.MemberID = MU.MemberID


   -- DELETE ANY OLD RECORDS FOR MEMBERS WITH MORE THAN 1 RECORD.
  DELETE
    FROM #MemberReimbursementHistory
    FROM #MemberReimbursementHistory MRH JOIN (SELECT MemberID, MAX(EnrollmentDate) EnrollmentDate
                                                 FROM #MemberReimbursementHistory
                                                GROUP BY MemberID
                                               HAVING COUNT(*) > 1) T2 ON MRH.MemberID = T2.MemberID
                                                                      AND MRH.EnrollmentDate <> T2.EnrollmentDate

   -- GET THE NEXT MemberReimbursementHistoryID AND UPDATE THE SQUENCE TABLE.

   SELECT @NewMemberReimbursementHistoryID = ISNULL(MAX(MemberReimbursementHistoryID),0)
   FROM tmpMemberReimbursementHistory
  
   IF @NewMemberReimbursementHistoryID = 0 
   BEGIN
        SELECT @NewMemberReimbursementHistoryID = ISNULL(MAX(MemberReimbursementHistoryID),0)
        FROM vMemberReimbursementHistory
   END

   -- INSERT THE NEW MemberReimbursementHistory RECORDS
  INSERT INTO tmpMemberReimbursementHistory(MemberReimbursementHistoryID,MembershipID, MemberID, ReimbursementProgramID, UsageFirstOfMonth,
                                            EnrollmentDate, MonthlyDues, EstimatedReimbursementAmount, 
                                            ActualReimbursementAmount, ClubID, ReimbursementErrorCodeID,
                                            ReimbursementQualifiedFlag, QualifiedClubUtilization)
  SELECT MemberReimbursementHistoryID + @NewMemberReimbursementHistoryID,MembershipID, MemberID, ReimbursementProgramID, UsageFirstOfMonth, EnrollmentDate, MonthlyDues,
         EstimatedReimbursementAmount, ActualReimbursementAmount, ClubID, ReimbursementErrorCodeID,
         ReimbursementQualifiedFlag, QualifiedClubUtilization
    FROM #MemberReimbursementHistory


  DROP TABLE #MemberReimbursementHistory
  DROP TABLE #TaxPercentage
  DROP TABLE #MemberUsage
  DROP TABLE #TotalMemberUsage
  DROP TABLE #tmpMemberUsage


END
