

--this procedure Returns Count of Leads and Joins by Club by day.

CREATE PROCEDURE [dbo].[mmsInternetPKMembershipCounts]
            
AS 

BEGIN

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SET XACT_ABORT ON
SET NOCOUNT ON
DECLARE @subject VARCHAR (250)
 SET @subject = 'InternetPK Membership Counts' + '(Database: ' + @@SERVERNAME + '.' + DB_Name() + ')'

 EXEC msdb.dbo.sp_send_dbmail  @recipients='vvs@lifetimefitness.com;glien@lifetimefitness.com;RWood1@lifetimefitness.com;JBrierley@lifetimefitness.com;SMyrick@lifetimefitness.com;dolson@lifetimefitness.com;DLeier@lifetimefitness.com;fdelarosa@lifetimefitness.com'
                             ,@subject=@subject
                             ,@dbuse='Report_MMS'
                             ,@query='
     
     
     DECLARE @LastDayOfLastMonth DATETIME
     DECLARE @FirstOfLastMonth DATETIME

     SET @LastDayOfLastMonth = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102) - DAY(GETDATE())
     SET @FirstOfLastMonth = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@LastDayOfLastMonth,112),1,6) + ''01'', 112)

     SELECT PMS.PKMembershipStagingID,ISNULL(C.ClubName,PMS.ClubID) ClubName,PMS.FromDataEntryFlag ,PMS.JoinDate
     INTO #T1
     FROM vPKMembershipStaging PMS LEFT JOIN vClub C ON PMS.ClubID = C.ClubID
     WHERE PMS.JoinDate >= @FirstOfLastMonth AND PMS.JoinDate < (CONVERT(VARCHAR,GETDATE(),110))
       AND PMS.FromDataEntryFlag IN(4,5)

     UNION
     
     SELECT PMS.PKMembershipStagingID,ISNULL(C.ClubName,PMS.ClubID) ClubName,PMS.FromDataEntryFlag ,PMS.JoinDate
     FROM vPKMembershipStagingLog PMS LEFT JOIN vClub C ON PMS.ClubID = C.ClubID
     WHERE PMS.JoinDate >= @FirstOfLastMonth AND PMS.JoinDate < (CONVERT(VARCHAR,GETDATE(),110))
       AND PMS.FromDataEntryFlag IN(4,5)

     SELECT JoinDate,ClubName,Count(*) Joins,0 Leads
     INTO #T2
     FROM #T1
     WHERE FromDataEntryFlag = 4 
     GROUP BY JoinDate,ClubName

     SELECT JoinDate,ClubName,0 JOINS,Count(*) LEADS
     INTO #T3
     FROM #T1 
     WHERE FromDataEntryFlag = 5
     GROUP BY JoinDate,ClubName

     UPDATE #T2
     SET LEADS = B.LEADS
     FROM #T2 A JOIN #T3 B ON A.JoinDate = B.JoinDate AND A.ClubName = B.ClubName

     INSERT INTO #T2
     SELECT A.JoinDate,A.ClubName,0,A.Leads
     FROM #T3 A LEFT JOIN #T2 B ON A.JoinDate = B.JoinDate AND A.ClubName = B.ClubName
     WHERE B.JOINDATE IS NULL

     SELECT CONVERT(VARCHAR(15),JoinDate,110) JoinDate,CONVERT(VARCHAR(30),ClubName) ClubName,Joins,Leads 
     FROM #T2 
     ORDER BY 1

     DROP TABLE #T1
     DROP TABLE #T2
     DROP TABLE #T3'

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity
               
END

