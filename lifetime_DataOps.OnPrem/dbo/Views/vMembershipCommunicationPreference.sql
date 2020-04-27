

CREATE VIEW dbo.vMembershipCommunicationPreference AS
  SELECT MembershipCommunicationPreferenceID, MembershipID, ValCommunicationPreferenceID, ActiveFlag
    FROM MMS.dbo.MembershipCommunicationPreference With (NOLOCK)


