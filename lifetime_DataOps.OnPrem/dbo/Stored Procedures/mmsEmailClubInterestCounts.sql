
CREATE PROCEDURE [dbo].[mmsEmailClubInterestCounts]
AS 
BEGIN

/* Emails the total count of Interests for Active Non-Junior Members on Non-Terminated Memberships 
   with the current number of Active Non-Junior Members and Non-Terminated Memberships.
   Will most likely be higher than DSSR results because of the lack of rules.                      */

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Interest Counts by Club ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current totals for Interests by Club for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'Interests_By_Club_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'beverson@lifetimefitness.com;JMaloney@lifetimefitness.com'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @Recipients
					,@copy_recipients = 'itdatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON

SELECT ms.ClubID, vmi.Description, COUNT(mci.MIPCategoryItemID) Count
INTO #MIPCounts
FROM vMembership ms
JOIN vMember m
  ON m.MembershipID = ms.MembershipID
JOIN vMIPMemberCategoryItem mmci
  ON m.MemberID = mmci.MemberID
JOIN vMIPCategoryItem mci
  ON mci.MIPCategoryItemID = mmci.MIPCategoryItemID
JOIN vValMIPItem vmi
  ON vmi.ValMIPItemID = mci.ValMIPItemID
WHERE ms.ValMembershipStatusID <> 1
  AND m.ValMemberTypeID <> 4
  AND mci.ActiveFlag = 1
  AND mmci.InsertedDateTime >= ''2008-12-02''
  AND mmci.InsertedDateTime < CAST(GETDATE() AS VARCHAR(11))
GROUP BY ms.ClubID, vmi.Description

SELECT  c.ClubName, c.ClubID, c.ClubCode,
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Aquatics''),0) [Aquatics],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Assessments & Testing''),0) [Assessments & Testing],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Basketball''),0) [Basketball],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Birthday parties''),0) [Birthday parties],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Cardio Enhancement''),0) [Cardio Enhancement],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Cycling''),0) [Cycling],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Golf''),0) [Golf],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Group Fitness''),0) [Group Fitness],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Healthy Living''),0) [Healthy Living],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Kids Activities''),0) [Kids Activities],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Kids Camps''),0) [Kids Camps],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Life Spa''),0) [Life Spa],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''LifeCafe - Healthy, Fresh Food''),0) [LifeCafe - Healthy, Fresh Food],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Nutrition Coaching''),0) [Nutrition Coaching],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Nutrition Supplements''),0) [Nutrition Supplements],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Personal Training''),0) [Personal Training],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Pilates''),0) [Pilates],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Racquetball''),0) [Racquetball],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Rock climbing''),0) [Rock climbing],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Running''),0) [Running],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Skiing''),0) [Skiing],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Squash''),0) [Squash],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Tennis''),0) [Tennis],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Triathlon''),0) [Triathlon],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Weight Loss''),0) [Weight Loss],
		ISNULL((SELECT Count FROM #MIPCounts WHERE ClubID = c.ClubID AND Description = ''Yoga''),0) [Yoga],
		ISNULL((SELECT SUM(COUNT) FROM #MIPCounts WHERE ClubID = c.ClubID),0) [Total],
		COUNT(DISTINCT ms.MembershipID) [Active Memberships],
		COUNT(DISTINCT m.MemberID) [Active Members]
FROM vClub c
LEFT JOIN vMembership ms
  ON (ms.ClubID = c.ClubID AND ms.ValMembershipStatusID <> 1)
LEFT JOIN vMember m
  ON (m.MembershipID = ms.MembershipID
	  AND m.ValMemberTypeID <> 4
      AND m.ActiveFlag = 1)
WHERE c.DisplayUIFlag = 1
GROUP BY c.ClubName, c.ClubID, c.ClubCode
ORDER BY c.ClubName

DROP TABLE #MIPCounts
SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END
