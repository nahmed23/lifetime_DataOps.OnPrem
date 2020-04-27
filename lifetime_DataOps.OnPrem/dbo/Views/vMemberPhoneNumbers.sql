


CREATE VIEW dbo.vMemberPhoneNumbers
	    (MembershipID
	    ,HomePhoneNumber
	    ,BusinessPhoneNumber
	    )
   AS SELECT Membership.MembershipID
	    ,'(' + RTRIM(HomePhone.AreaCode) + ')' + SUBSTRING(HomePhone.Number,1,3)+ '-' + SUBSTRING(HomePhone.Number,4,4)
	    ,'(' + RTRIM(BizPhone.AreaCode)  + ')' + SUBSTRING(BizPhone.Number,1,3) + '-' + SUBSTRING(BizPhone.Number,4,4)
	FROM MMS.dbo.Membership		Membership
	LEFT OUTER JOIN MMS.dbo.MembershipPhone  HomePhone 
		ON (Membership.MembershipID = HomePhone.MembershipID AND HomePhone.ValPhoneTypeID = 1) 
	LEFT OUTER JOIN MMS.dbo.MembershipPhone  BizPhone 
		ON (Membership.MembershipID = BizPhone.MembershipID AND BizPhone.ValPhoneTypeID = 2) 



