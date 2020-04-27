




CREATE VIEW dbo.vInternetMembership
AS
     SELECT PMS.PKMembershipStagingID,ISNULL(C.ClubName,PMS.ClubID) ClubName,PMS.FromDataEntryFlag ,PMS.JoinDate
     FROM vPKMembershipStaging PMS LEFT JOIN vClub C ON PMS.ClubID = C.ClubID
     WHERE PMS.FromDataEntryFlag IN(4,5)

     UNION
     
     SELECT PMS.PKMembershipStagingID,ISNULL(C.ClubName,PMS.ClubID) ClubName,PMS.FromDataEntryFlag ,PMS.JoinDate
     FROM vPKMembershipStagingLog PMS LEFT JOIN vClub C ON PMS.ClubID = C.ClubID
     WHERE PMS.FromDataEntryFlag IN(4,5)




