CREATE VIEW dbo.vEmailEvent AS 
SELECT EmailEventID,Event,dataCollectorClass,Description,SampleContentPath
FROM MMS.dbo.EmailEvent WITH(NOLOCK)
