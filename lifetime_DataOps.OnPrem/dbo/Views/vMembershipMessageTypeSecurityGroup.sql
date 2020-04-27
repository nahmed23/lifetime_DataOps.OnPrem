


CREATE VIEW dbo.vMembershipMessageTypeSecurityGroup
AS
SELECT MembershipMessageTypeSecurityGroupID, 
    ValMembershipMessageTypeID, ValSecurityGroupID
FROM MMS.dbo.MembershipMessageTypeSecurityGroup With (NOLOCK)



