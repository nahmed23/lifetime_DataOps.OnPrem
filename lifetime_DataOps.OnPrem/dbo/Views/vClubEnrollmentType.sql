

CREATE VIEW dbo.vClubEnrollmentType
AS
SELECT     ClubEnrollmentTypeID, ClubID, ValEnrollmentTypeID
FROM MMS.dbo.ClubEnrollmentType With (NOLOCK)


