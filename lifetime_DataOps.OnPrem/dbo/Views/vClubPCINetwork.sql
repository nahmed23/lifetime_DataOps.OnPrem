CREATE VIEW dbo.vClubPCINetwork AS 
SELECT ClubPCINetworkID,ClubID,SubnetAddress,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ClubPCINetwork WITH(NOLOCK)
