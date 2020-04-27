
CREATE VIEW dbo.vAutoShipAcknowledgementMember
AS
SELECT     AutoShipAcknowledgementMemberID, AcknowledgementDate, MemberID, MemberShipID, ValAutoShipActionID, InsertedDateTime, 
                      UpdatedDateTime
FROM         MMS.dbo.AutoShipAcknowledgementMember

