


CREATE VIEW dbo.vPrimaryPhone
	    (MembershipID
	    ,ValPhoneTypeID)
   AS SELECT Membership.MembershipID
	    ,MIN(MembershipPhone.ValPhoneTypeID)
	FROM MMS.dbo.Membership		Membership
	    ,MMS.dbo.MembershipPhone	MembershipPhone
       WHERE Membership.MembershipID  = MembershipPhone.MembershipID 
    GROUP BY Membership.MembershipID


