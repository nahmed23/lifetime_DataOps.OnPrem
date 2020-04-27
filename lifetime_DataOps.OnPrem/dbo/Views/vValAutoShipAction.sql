

CREATE VIEW dbo.vValAutoShipAction
AS
SELECT     ValAutoShipActionID, Description, SortOrder, Abbreviation, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.ValAutoShipAction WITH (NoLock)


