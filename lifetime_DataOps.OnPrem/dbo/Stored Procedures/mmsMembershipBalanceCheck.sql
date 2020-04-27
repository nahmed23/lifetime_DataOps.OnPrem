


CREATE PROCEDURE [dbo].[mmsMembershipBalanceCheck](@Count INT OUTPUT)
AS

-- This procedures validates the MembershipBalance records CurrentBalance and
-- CommittedBalance against balances calculated from the MMSTran records

SET XACT_ABORT ON
SET NOCOUNT ON
DECLARE @CheckDate AS DATETIME

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SET @CheckDate = GETDATE()
--select all memberships and their CurrentBalance and CommittedBalance
SELECT MS.MembershipID,
	   MB.CurrentBalance + ISNULL(MB.CurrentBalanceProducts,0) AS CurrentBalance,
	   MB.CommittedBalance + ISNULL(MB.CommittedBalanceProducts,0) AS CommittedBalance
  INTO #T3
  FROM vMembership MS
       LEFT JOIN vMembershipBalance MB
         ON MS.MembershipID = MB.MembershipID
 WHERE MS.MembershipTypeID <> 134 -- Don't include the house accounts


-- Calculate the current balance for all Memberships using the MMSTrans
SELECT MembershipID, SUM(COALESCE(ConvertedAmount,TranAmount)) CalculatedCurrentBalance
  INTO #T1
  FROM vMMSTran
 WHERE COALESCE(ConvertedAmount,TranAmount) <> 0.00
   AND TranVoidedID IS NULL
   AND MembershipID <> -1
   AND ISNULL(InsertedDateTime,'Jan 01, 1990') <= @CheckDate 
 GROUP BY MembershipID

-- Calculate the non committed balance for all Memberships with transaction in non-closed drawers
SELECT MT.MembershipID, SUM(COALESCE(MT.ConvertedAmount,MT.TranAmount)) NonCommittedBalance
  INTO #T2
  FROM vMMSTran MT
       JOIN vDrawerActivity DA
         ON MT.DrawerActivityID = DA.DrawerActivityID
        AND DA.ValDrawerStatusID <> 3 -- Only include open/pending drawers
 WHERE COALESCE(MT.ConvertedAmount,MT.TranAmount) <> 0.00
   AND MT.TranVoidedID IS NULL
   AND MT.MembershipID <> -1
   AND ISNULL(MT.InsertedDateTime,'Jan 01, 1990') <= @CheckDate 
 GROUP BY MembershipID

-- Determine the memberships that have either a CurrentBalance or CommittedBalance that
-- doesn't match the calculated balance
SELECT T3.MembershipID,
       T3.CurrentBalance,
       ISNULL(T1.CalculatedCurrentBalance, 0.00) CalculatedCurrentBalance,
       T3.CommittedBalance,
       ISNULL(T1.CalculatedCurrentBalance, 0.00)
       - ISNULL(T2.NonCommittedBalance, 0.00) CalculatedCommittedBalance
  INTO #T4
  FROM #T3 T3
       LEFT JOIN #T1 T1
         ON T3.MembershipID = T1.MembershipID
       LEFT JOIN #T2 T2
         ON T3.MembershipID = T2.MembershipID
 WHERE (T3.CurrentBalance <> ISNULL(T1.CalculatedCurrentBalance, 0.00)
        OR T3.CommittedBalance <> ISNULL(T1.CalculatedCurrentBalance, 0.00)
                                  - ISNULL(T2.NonCommittedBalance, 0.00))


--DELETE ALL MEMBERSHIPS THAT HAVE AN MMSTRAN CREATED IN THE LAST ONE HOUR
DELETE #T4
FROM #T4 T JOIN vMMSTran MT ON T.MembershipID = MT.MembershipID
WHERE MT.InsertedDateTime > DATEADD(hh, -1,@CheckDate)

--DELETE ALL MEMBERSHIPS THAT HAVE AN VOIDED MMSTRAN IN THE LAST ONE HOUR
DELETE #T4
FROM #T4 T JOIN vMMSTran MT ON T.MembershipID = MT.MembershipID
           JOIN vTranVoided TV ON MT.TranVoidedID = TV.TranVoidedID
WHERE TV.InsertedDateTime > DATEADD(hh, -1,@CheckDate)

SELECT @Count = COUNT(*)
  FROM #T4

IF @Count > 0
BEGIN
  PRINT 'Count of incorrect Balances: ' + CONVERT(VARCHAR,@Count)
  PRINT ''
  IF @Count > 200
  BEGIN
    PRINT 'Only the first 200 incorrect balances are shown here'
    PRINT ''
  END
  SELECT TOP 200 *
    FROM #T4

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

