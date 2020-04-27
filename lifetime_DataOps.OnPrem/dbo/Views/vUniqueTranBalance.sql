


CREATE VIEW dbo.vUniqueTranBalance
	    (MembershipID)  
   AS SELECT Membership.MembershipID
	FROM MMS.dbo.Membership		Membership
	    ,MMS.dbo.TranBalance		TranBalance
       WHERE Membership.MembershipID  = TranBalance.MembershipID 
	AND TranBalance.TranBalanceAmount <> 0
   GROUP BY Membership.MembershipID  


