-------------------------------------------- dbo.mmsPurgeAccount_MembershipList
-- This procedure will return memberhip ids for memberships that
-- meet the following criteria.
--
-- 1.) Membership is Terminated
-- 2.) Membership's termination date is older than 6 months
-- 3.) Membership has no "Active" recurring products
-- 4.) Most recent transaction for the membership is older than 4 months
-- 5.) Membership's balance is less than or equal to $0
-- 6.) Membership has an account number.
--
-------------------------------------------------------------- Create Procedure
CREATE PROCEDURE
       dbo.
       mmsPurgeAccount_MembershipList
          @a_club_id  INT
AS

SET NOCOUNT ON;

                                                 -- if the club id is not
                                                 -- defined, exit
IF ( @a_club_id IS NULL
     OR
     @a_club_id  = 0 )
   RETURN

DECLARE @l_count        INT,
        @l_current_date DATETIME

SET @l_current_date = GETDATE()
                                                 -- return a list of memberships
                                                 -- to update
SELECT DISTINCT
       ms.MembershipID
FROM
       vMembership                      ms
       JOIN
       vMembershipBalance               mb
       ON
          ms.MembershipID             = mb.MembershipID
       JOIN
       vEFTAccount                      ea
       ON
          ms.MembershipID             = ea.MembershipID
       LEFT JOIN
       vCreditCardAccount               cca
       ON
          ea.CreditCardAccountID      = cca.CreditCardAccountID
       LEFT JOIN
       vBankAccount                     ba
       ON
          ea.BankAccountID            = ba.BankAccountID
                                                 -- active recurrent prods
       LEFT JOIN
       vMembershipRecurrentProduct      Amrp
       ON
          ms.MembershipID             = Amrp.MembershipID
          AND
          Amrp.TerminationDate       IS NULL
                                                 -- terminated recurrent prods
       LEFT JOIN
       ( SELECT MembershipID,
                MAX( TerminationDate )
                   AS MaxTerminationDate
         FROM   vMembershipRecurrentProduct
         GROUP  BY MembershipID )       Tmrp
       ON
          ms.MembershipID             = Tmrp.MembershipID
       LEFT JOIN
       ( SELECT MembershipID,
                MAX( TranDate )
                   AS MaxTranDate
         FROM   vMMSTran
         GROUP  BY MembershipID )       mt
       ON
          ms.MembershipID             = mt.MembershipID
WHERE
       ms.ClubID                      = @a_club_id
       AND
       ms.ValMembershipStatusID       = 1
       AND
       ms.ExpirationDate              < DATEADD( m, -6, @l_current_date )
       AND
       Amrp.MembershipID             IS NULL
       AND
       ( Tmrp.MaxTerminationDate      < @l_current_date
         OR
         Tmrp.MembershipID           IS NULL )
       AND
       ( mt.MaxTranDate               < DATEADD( m, -6, @l_current_date )
         OR
         mt.MembershipID             IS NULL )
       AND
       mb.CurrentBalance             <= 0
       AND
       ( cca.EncryptedAccountNumber  IS NOT NULL
         OR
         ba.AccountNumber            IS NOT NULL );

                                                 -- get count
SET @l_count = @@ROWCOUNT;

RETURN @l_count;
