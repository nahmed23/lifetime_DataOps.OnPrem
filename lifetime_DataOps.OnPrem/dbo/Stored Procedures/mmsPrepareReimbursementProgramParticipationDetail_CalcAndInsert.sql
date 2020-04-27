
CREATE PROCEDURE mmsPrepareReimbursementProgramParticipationDetail_CalcAndInsert AS
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
       MemberID                     INT,
       MembershipID                 INT,
       AccessMembershipFlag         INT,
       DuesPrice                    MONEY,
       SalesTaxPercentage           DECIMAL(4,2),
       MembershipExpirationDate     DATETIME,
       ValTerminationReasonID       INT,
       ValPreSaleID                 INT,
       ValMembershipStatusID        INT,
       MembershipProductDescription VARCHAR(50))

INSERT INTO #ProgramParticipation
SELECT vReimbursementProgram.ReimbursementProgramID,
       vReimbursementProgram.ReimbursementProgramName,
       vMemberReimbursement.MemberID,
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
       END AS AccessMembershipFlag,
       vClubProductPriceTax.Price AS DuesPrice,
       IsNull(Sum(vClubProductPriceTax.TaxPercentage),0) as SalesTaxPercentage,
       vMembership.ExpirationDate,
       vMembership.ValTerminationReasonID,
       vClub.ValPreSaleID,
       vMembership.ValMembershipStatusID,
       vProduct.Description
  FROM vReimbursementProgram
  JOIN vMemberReimbursement
    ON vReimbursementProgram.ReimbursementProgramID = vMemberReimbursement.ReimbursementProgramID
  JOIN vMember
    ON vMember.MemberID = vMemberReimbursement.MemberID
  JOIN vMembership
    ON vMembership.MembershipID = vMember.MembershipID
  JOIN vMembershipType
    ON vMembershipType.MembershipTypeID = vMembership.MembershipTypeID
  JOIN vClubProductPriceTax
    ON vClubProductPriceTax.ClubID = vMembership.ClubID
   AND vClubProductPriceTax.ProductID = vMembershipType.ProductID
  JOIN vClub
    ON vClub.ClubID = vMembership.ClubID
  JOIN vProduct
    ON vProduct.ProductID = vMembershipType.ProductID
 WHERE vMemberReimbursement.EnrollmentDate <= @Today
   AND (vMemberReimbursement.TerminationDate >= @Today OR vMemberReimbursement.TerminationDate IS NULL)
   AND (vMembership.ExpirationDate >= @Today OR vMembership.ExpirationDate IS NULL)
 GROUP BY vReimbursementProgram.ReimbursementProgramID,
       vReimbursementProgram.ReimbursementProgramName,
       vMemberReimbursement.MemberID,
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
       END,
       vClubProductPriceTax.Price,
       vMembership.ExpirationDate,
       vMembership.ValTerminationReasonID,
       vClub.ValPreSaleID,
       vMembership.ValMembershipStatusID,
       vProduct.Description

DELETE FROM ReimbursementProgramParticipationDetail
 WHERE YearMonth = @TodayYearMonth

INSERT INTO ReimbursementProgramParticipationDetail
SELECT ReimbursementProgramID,
       ReimbursementProgramName,
       MembershipID,
       COUNT(MemberID) AS MemberCount,
       MAX(AccessMembershipFlag) AS AccessMembershipFlag,
       DuesPrice,
       SalesTaxPercentage,
       MembershipExpirationDate,
       ValTerminationReasonID,
       ValPreSaleID,
       ValMembershipStatusID,
       MembershipProductDescription,
       @Today AS InsertedDate,
       @TodayMonthYear AS MonthYear,
       @TodayYearMonth AS YearMonth
  FROM #ProgramParticipation
 GROUP BY ReimbursementProgramID,
       ReimbursementProgramName,
       MembershipID,
       DuesPrice,
       SalesTaxPercentage,
       MembershipExpirationDate,
       ValTerminationReasonID,
       ValPreSaleID,
       ValMembershipStatusID,
       MembershipProductDescription
 ORDER BY ReimbursementProgramID,
       MembershipID

DROP TABLE #ProgramParticipation

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

