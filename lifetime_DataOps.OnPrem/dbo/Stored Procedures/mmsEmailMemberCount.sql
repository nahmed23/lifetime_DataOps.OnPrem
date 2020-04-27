

CREATE PROCEDURE [dbo].[mmsEmailMemberCount] AS
BEGIN
  SET NOCOUNT ON

  DECLARE @CheckDate DATETIME
  SELECT @CheckDate = MAX(UsageDateTime)
    FROM MMS_DB04.dbo.MemberUsage

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  IF @CheckDate < DATEADD(d, -3, GETDATE())
  BEGIN
    EXEC msdb.dbo.sp_send_dbmail   @recipients='dolson@lifetimefitness.com;vvs@lifetimefitness.com;glien@lifetimefitness.com'
								  ,@subject='Job mmsEmailMemberCount Failed'
                                  ,@message='The job mmsEmailMemberCount failed bacause the data in MMS_DB04 did not get refreshed.'
  END
  ELSE
  BEGIN
    EXEC msdb.dbo.sp_send_dbmail   @recipients='dolson@lifetimefitness.com;vvs@lifetimefitness.com;glien@lifetimefitness.com;vbarge@lifetimefitness.com;lsetterstrom@lifetimefitness.com;rmendel@lifetimefitness.com;wbertch@lifetimefitness.com;bzempel@lifetimefitness.com'
								  ,@subject='Member Count Results'
								  ,@dbuse='Report_MMS'
								  ,@query='
    DECLARE @Members INT
    DECLARE @Juniors INT

    SELECT @Members = COUNT(DISTINCT M.MemberID)
      FROM vMember M JOIN vMembership MS ON M.MembershipID = MS.MembershipID
     WHERE M.ActiveFlag = 1
       AND M.ValMemberTypeID <> 4
       AND (MS.ExpirationDate > GETDATE() OR MS.ExpirationDate IS NULL)

    SELECT @Juniors = COUNT(DISTINCT M.MemberID)
      FROM vMember M JOIN vMembership MS ON M.MembershipID = MS.MembershipID
     WHERE M.ActiveFlag = 1
       AND M.ValMemberTypeID = 4
       AND (MS.ExpirationDate > GETDATE() OR MS.ExpirationDate IS NULL)

    PRINT ''Number of Active, Non-Junior Members:  '' + CAST(@Members AS VARCHAR)
    PRINT ''Number of Active, Junior Members:  '' + CAST(@Juniors AS VARCHAR)'
  END
-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

