

CREATE VIEW dbo.vValReimbursementTerminationReason
AS
SELECT     ValReimbursementTerminationReasonID, Description, SortOrder, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.ValReimbursementTerminationReason WITH (NoLock)


