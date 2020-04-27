
CREATE PROCEDURE mmsPrepareReimbursementProgramParticipationSummary_CalcAndInsert AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

DECLARE @FirstOfNextMonth DATETIME,
        @Today DATETIME,
        @TodayMonthYear VARCHAR(15),
        @TodayYearMonth VARCHAR(6)

SET @FirstOfNextMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR, DATEADD(MONTH, 1, GETDATE()),112),1,6) + '01', 112)
SET @Today = CONVERT(DATETIME, CONVERT(VARCHAR(10), GETDATE(), 101) , 101)
SET @TodayMonthYear = DATENAME(MONTH, GETDATE()) + ', ' + DATENAME(YEAR, GETDATE())
SET @TodayYearMonth = DATENAME(YEAR, GETDATE()) + 
    CASE LEN(DATEPART(MONTH, GETDATE()))
         WHEN 1
              THEN '0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))
              ELSE CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))
    END

CREATE TABLE #ProgramParticipation(
       ReimbursementProgramID       INT,
       ReimbursementProgramName     VARCHAR(50),
       MembershipID                 INT,
       AccessMembershipFlag         INT)

INSERT INTO #ProgramParticipation
SELECT vReimbursementProgram.ReimbursementProgramID,
       vReimbursementProgram.ReimbursementProgramName,
       vMembership.MembershipID,
       CASE
            WHEN vMembershipType.ValCheckInGroupID != 0
                 AND (vMembership.ExpirationDate IS NULL
                      OR (vMembership.ValTerminationReasonID != 24 AND vMembership.ExpirationDate >= @Today)
                      OR (vMembership.ValTerminationReasonID = 24 AND vMembership.ExpirationDate >= @FirstOfnextMonth))
                 AND (vClub.ValPreSaleID = 1 AND vMembership.ValMembershipStatusID NOT IN (3,5,7)
                      OR vClub.ValPreSaleID <> 1)
                 AND vProduct.Description NOT LIKE '%Short%'
                 AND vProduct.Description NOT LIKE '%Empl%'
                 AND vProduct.Description NOT LIKE '%Trade%'
                 AND vProduct.Description NOT LIKE '%Invest%'
                 AND vProduct.Description NOT LIKE '%House%'
            THEN 1
            ELSE 0
       END AS AccessMembershipFlag
  FROM vReimbursementProgram
  JOIN vMemberReimbursement
    ON vReimbursementProgram.ReimbursementProgramID = vMemberReimbursement.ReimbursementProgramID
  JOIN vMember
    ON vMember.MemberID = vMemberReimbursement.MemberID
  JOIN vMembership
    ON vMembership.MembershipID = vMember.MembershipID
  JOIN vMembershipType
    ON vMembershipType.MembershipTypeID = vMembership.MembershipTypeID
  JOIN vClub
    ON vClub.ClubID = vMembership.ClubID
  JOIN vProduct
    ON vProduct.ProductID = vMembershipType.ProductID
 WHERE vMemberReimbursement.EnrollmentDate <= @Today
   AND (vMemberReimbursement.TerminationDate >= @Today OR vMemberReimbursement.TerminationDate IS NULL)
   AND (vMembership.ExpirationDate >= @Today OR vMembership.ExpirationDate IS NULL)

DELETE FROM ReimbursementProgramParticipationSummary
 WHERE YearMonth = @TodayYearMonth

INSERT INTO ReimbursementProgramParticipationSummary
SELECT ReimbursementProgramID,
       ReimbursementProgramName,
       Sum(AccessMembershipFlag) AS AccessMembershipCount,
       @Today AS InsertedDate,
       @TodayMonthYear AS MonthYear,
       @TodayYearMonth AS YearMonth
  FROM #ProgramParticipation
 GROUP BY ReimbursementProgramID,
       ReimbursementProgramName
 ORDER BY ReimbursementProgramID


DROP TABLE #ProgramParticipation

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

