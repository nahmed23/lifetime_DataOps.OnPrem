
CREATE PROC [dbo].[mmsCorpUser_Memberusage_Scheduled_AdvantaHealth] 


AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @FirstOfMonth DATETIME
DECLARE @Yesterday    DATETIME

SET @FirstOfMonth = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @Yesterday = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE()-1,110),110)


EXEC mmsCorpUser_Memberusage @FirstOfMonth,@Yesterday,'78373','Primary|Partner|Secondary|Junior',0,'Membership Company'


END
