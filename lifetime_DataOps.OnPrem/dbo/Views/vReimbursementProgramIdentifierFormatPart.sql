

CREATE VIEW dbo.vReimbursementProgramIdentifierFormatPart
AS
SELECT     ReimbursementProgramIdentifierFormatPartID, ReimbursementProgramIdentifierFormatID, FieldName, FieldSize, FieldValidationRule, FieldSequence, 
                      InsertedDateTime, UpdatedDateTime, FieldValidationErrorMessage
FROM         MMS.dbo.ReimbursementProgramIdentifierFormatPart WITH (NoLock)


