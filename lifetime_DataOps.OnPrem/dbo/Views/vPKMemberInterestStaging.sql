CREATE VIEW dbo.vPKMemberInterestStaging AS 
SELECT PKMemberInterestStagingID,InterestID,PKMemberStagingID,InsertedDateTime
FROM MMS.dbo.PKMemberInterestStaging WITH(NOLOCK)
