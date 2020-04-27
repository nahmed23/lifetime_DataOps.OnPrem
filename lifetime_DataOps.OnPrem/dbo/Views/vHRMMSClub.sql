CREATE VIEW dbo.vHRMMSClub AS 
SELECT HRMMSClubID,HRClub,MMSClubID,ReportingRegionID,NetworkClubGMPath,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.HRMMSClub WITH(NOLOCK)
