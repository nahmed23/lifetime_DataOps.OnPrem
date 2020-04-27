




CREATE VIEW dbo.vActiveAssociateMemberships
AS

SELECT MRP.MembershipID, MAX(MRP.ProductID) AS ProductID, MAX(MRP.ActivationDate) AS AssociateMembershipActivationDate
FROM dbo.vMembershipRecurrentProduct MRP WITH (NoLock)
WHERE (MRP.TerminationDate IS NULL OR
       MRP.TerminationDate >= Getdate()) 
GROUP BY MRP.MembershipID



