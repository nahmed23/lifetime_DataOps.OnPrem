
CREATE PROC mmsPT_DSSR_NonJunior_NewMember_Detail 
    AS

BEGIN

   SET XACT_ABORT ON
   SET NOCOUNT ON

DECLARE @FirstOfPriorMonth DATETIME
DECLARE @Yesterday DATETIME

SET @FirstOfPriorMonth = DATEADD(MONTH,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))
SET @Yesterday = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(DAY,-1,(GETDATE())),110),110)

SELECT vMember.MemberID,
       vMembership.ClubID,
       vMembership.CreatedDateTime,
       vMembership.MembershipID
  FROM vMember
  JOIN vMembership
    ON vMember.MembershipID = vMembership.MembershipID
 WHERE vMember.ValMemberTypeID IN (1, 2, 3)
   AND vMembership.CreatedDateTime BETWEEN @FirstOfPriorMonth and @Yesterday
 ORDER BY vMember.MemberID

END

