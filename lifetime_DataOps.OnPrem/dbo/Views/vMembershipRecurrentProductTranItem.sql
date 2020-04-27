CREATE VIEW [dbo].[vMembershipRecurrentProductTranItem]
AS
SELECT MembershipRecurrentProductTranItemID, MembershipRecurrentProductID, TranItemID
FROM MMS_Archive.dbo.MembershipRecurrentProductTranItem WITH (NOLOCK)
