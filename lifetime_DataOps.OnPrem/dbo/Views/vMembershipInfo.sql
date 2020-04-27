
CREATE VIEW [dbo].[vMembershipInfo]
AS
SELECT  VMS.MembershipID, VM.MemberID, VC.ClubName, VM.LastName, VM.FirstName, VMA.AddressLine1, VMA.AddressLine2, VMA.City, 
                      VMA.StateAbbreviation AS StateAbbreviation, VMA.Zip, DATEDIFF(YY, VM.DOB, GETDATE()) AS Age, VM.DOB DOB, VM.Gender, VMS.ActivationDate ActivationDate, 
                      CASE WHEN VMS.ExpirationDate IS NULL
                           THEN CONVERT(NUMERIC(10,2),CONVERT(NUMERIC(10,2),DATEDIFF( month, ISNULL( VMS.CreatedDateTime, VM.JoinDate), GETDATE()))/12.00 )
                           ELSE CONVERT(NUMERIC(10,2),CONVERT(NUMERIC(10,2),DATEDIFF( month, ISNULL( VMS.CreatedDateTime, VM.JoinDate), VMS.ExpirationDate)) /12.00)
                           END MembershipLength,
                      VMS.MembershipTypeID AS ProductID, ISNULL( VM.JoinDate, 'JAN 01 1992') AS JoinDate, 
                      CASE WHEN CompanyID IS NULL THEN 0
                      ELSE 1
                      END CorpAffiliationFlag, LEFT(VVMTFS.Description, 6) AS MembershipSizeDesc, VC.DomainNamePrefix,
                      VMA.Latitude, VMA.Longitude, VMA.GeoResults,VMA.AccessMembershipFlag

FROM                  dbo.vMembership VMS INNER JOIN
                      dbo.vMember VM ON VMS.MembershipID = VM.MembershipID  INNER JOIN
                      dbo.vClub VC ON VMS.ClubID = VC.ClubID INNER JOIN
                      dbo.vMapInfoMembershipAddress VMA ON VMS.MembershipID = VMA.MembershipID INNER JOIN
                      dbo.vMembershipType VMT ON VMS.MembershipTypeID = VMT.MembershipTypeID INNER JOIN
                      dbo.vValMembershipTypeFamilyStatus VVMTFS ON 
                                VMT.ValMembershipTypeFamilyStatusID = VVMTFS.ValMembershipTypeFamilyStatusID

WHERE VM.ValMemberTypeID = 1
