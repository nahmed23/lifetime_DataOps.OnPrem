CREATE VIEW dbo.vLTFEBParty AS 
SELECT LTFEBPartyID,ltfeb_party_id,MembershipID,MemberID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFEBParty WITH(NOLOCK)
