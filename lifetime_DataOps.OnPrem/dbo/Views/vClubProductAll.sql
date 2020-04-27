


CREATE VIEW dbo.vClubProductAll
AS
SELECT ClubID, ProductID
FROM MMS.dbo.Club A CROSS JOIN MMS.dbo.Product B
WHERE A.DisplayUIFlag = 1



