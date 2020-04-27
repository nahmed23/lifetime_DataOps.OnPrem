CREATE VIEW dbo.vClubAttribute AS 
SELECT ClubAttributeID,MMSClubID,ValClubAttributeTypeID,AttributeValue,EffectiveFromDateTime,EffectiveThruDateTime
FROM MMS.dbo.ClubAttribute WITH(NOLOCK)
