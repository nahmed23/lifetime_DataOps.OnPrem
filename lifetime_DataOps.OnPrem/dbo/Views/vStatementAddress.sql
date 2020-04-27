



CREATE VIEW dbo.vStatementAddress
	    (MembershipID
	    ,CompanyName
	    ,FirstName
	    ,LastName
	    ,AddressLine1
	    ,AddressLine2
	    ,City 
	    ,ValStateID
	    ,Zip
            ,ValCountryID
	    )
   AS SELECT Membership.MembershipID
	    ,BillingAddress.CompanyName
	    ,ISNULL(BillingAddress.FirstName,Member.FirstName)
	    ,ISNULL(BillingAddress.LastName,Member.LastName)
	    ,ISNULL(BillingAddress.AddressLine1,MembershipAddress.AddressLine1)
	    ,ISNULL(BillingAddress.AddressLine2,MembershipAddress.AddressLine2)
	    ,ISNULL(BillingAddress.City,MembershipAddress.City)
	    ,ISNULL(BillingAddress.ValStateID,MembershipAddress.ValStateID)
	    ,ISNULL(BillingAddress.Zip,MembershipAddress.Zip)
	    ,ISNULL(BillingAddress.ValCountryID,MembershipAddress.ValCountryID)
	FROM MMS.dbo.Membership		Membership
	    ,MMS.dbo.Member		Member
	    ,MMS.dbo.MembershipAddress	MembershipAddress
	     LEFT OUTER JOIN MMS.dbo.BillingAddress	BillingAddress ON (MembershipAddress.MembershipID = BillingAddress.MembershipID) 	
       WHERE Membership.MembershipID  	= MembershipAddress.MembershipID 	
	 AND Member.MembershipID	= Membership.MembershipID 
	 AND Member.ValMemberTypeID	= 1 



