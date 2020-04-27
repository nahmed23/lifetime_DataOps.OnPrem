

-- This procedure verifies that the MembershipBalance is correct after running EFT.

CREATE PROCEDURE [dbo].[mmsMembershipTypeAgreementValidate]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON 


DECLARE @Count INT
DECLARE @DBName VARCHAR(100)
DECLARE @EmailGroup VARCHAR(100)
DECLARE @LoopCount INT
DECLARE @subject VARCHAR (250)
DECLARE @Query VARCHAR(8000)

SET @Query = 'SELECT ClubName, mtype.membershiptypeid AS MembershipTypeID, p.description MembershipTypeDescription, pm.description AS PricingMethod, SoldInPK ,cp.Price
              FROM vClub c JOIN vClubProduct cp ON c.ClubID = cp.ClubID
                           JOIN vProduct p ON p.ProductID = cp.ProductID
                           JOIN vMembershiptype mtype ON mtype.ProductID = p.ProductID
                           JOIN vValPricingMethod pm on mtype.ValPricingMethodID = pm.ValPricingMethodID
                           LEFT JOIN vMembershipTypeClubAgreement mtca on mtca.MembershipTypeID = mtype.MembershipTypeID 
                                AND mtca.ClubID = c.ClubID 
		                        AND agreementid IN (SELECT AgreementID FROM vAgreement agree WHERE agree.ValContractTypeID in (3))
             WHERE p.ValProductStatusID = 1 
               AND SoldInPK = 1
               AND mtca.MembershipTypeClubAgreementID IS NULL
               AND c.ClubDeActivationDate IS NULL  --Exclude clubs that have been deactivated
             ORDER BY p.description'
SET @EmailGroup = 'DSchmidt@lifetimefitness.com;ISDataWarehouseSupport@lifetimefitness.com;POneal@lifetimefitness.com'
--SET @EmailGroup = 'IT-TEST'
SELECT @Count = COUNT(*) 
FROM vClub c
JOIN vClubProduct cp ON c.ClubID = cp.ClubID
JOIN vProduct p ON p.ProductID = cp.ProductID
JOIN vMembershiptype mtype ON mtype.ProductID = p.ProductID
JOIN vValPricingMethod pm on mtype.ValPricingMethodID = pm.ValPricingMethodID
LEFT JOIN vMembershipTypeClubAgreement mtca on mtca.MembershipTypeID = mtype.MembershipTypeID 
          AND mtca.ClubID = c.ClubID 
		  AND agreementid IN (SELECT AgreementID FROM vAgreement agree WHERE agree.ValContractTypeID in (3))
WHERE p.ValProductStatusID = 1 
AND SoldInPK = 1
AND mtca.MembershipTypeClubAgreementID IS NULL
AND c.ClubDeActivationDate IS NULL  --Exclude clubs that have been deactivated
IF @Count > 0 
BEGIN
  SELECT @DBName = DB_Name()
  SET @subject = 'The following Membership Types are missing General Terms Agreements at the specified clubs:' + '(Database: ' + @@SERVERNAME + '.' + DB_Name() + ')'
  EXEC msdb.dbo.sp_send_dbmail   @recipients = @EmailGroup
                                ,@copy_recipients = 'RSwenson2@lifetimefitness.com'
								,@query = @Query
							    ,@subject = @subject
								,@execute_query_database = @DBName
								,@query_result_width = 500
END

SELECT @RowsProcessed = @Count
SELECT @Description = 'Number of MembershipTypes with out Agreements'


END

