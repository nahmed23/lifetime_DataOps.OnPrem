

CREATE VIEW dbo.vClubActivityArea
AS
SELECT ClubActivityAreaID, ClubID, ValActivityAreaID
FROM MMS.dbo.ClubActivityArea With (NOLOCK)

