
CREATE PROCEDURE [dbo].[mmsEmailVouchers]
AS 
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON

/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'Vouchers ' + CONVERT(VARCHAR(12),GETDATE(),110)

DECLARE @BodyText VARCHAR(100)
SET @BodyText = 'Here are the current list of Vouchers for ' + CONVERT(VARCHAR(12),GETDATE(),101)

DECLARE @FileName VARCHAR(50)
SET @FileName = 'Vouchers_' + CONVERT(VARCHAR(12),GETDATE(),110) +'.csv'

DECLARE @Recipients VARCHAR(100)
SET @Recipients = 'PZebott@LifeTimeFitness.com'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @Recipients
					,@copy_recipients = 'itdatabase@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_width = 1000
				    ,@query_result_separator = '	' --tab
                    ,@execute_query_database = 'Report_MMS'
					,@query='
SET ANSI_WARNINGS OFF
SET NOCOUNT ON

SELECT  mmt.MMSTranID,           
        TranDate, 
        m.MemberID,
        m.LastName + '', '' + m.FirstName [MemberName],
        ship.CreatedDateTime [MembershipCreated],
        ClubName,
        dept.Description [Department],
        prod.Description [Product],
        prod.GLAccountNumber,
        prod.GLSubAccountNumber,
        ti.ItemAmount,
        pay.PaymentAmount,
        e.EmployeeID,
        e.LastName + '', '' + e.FirstName [Employee Name]
FROM vMMSTran mmt               
JOIN vPayment pay ON mmt.MMSTranID = pay.MMSTranID                      
JOIN vTranItem ti ON mmt.MMSTranID = ti.MMSTranID
JOIN vMember m ON mmt.MemberID = m.MemberID
JOIN vClub c ON mmt.ClubID = c.ClubID
JOIN vProduct prod ON ti.ProductID = prod.ProductID
JOIN vMembership ship ON mmt.MembershipID = ship.MembershipID
JOIN vDepartment dept ON prod.DepartmentID = dept.DepartmentID
LEFT JOIN vSaleCommission sc ON ti.TranItemID = sc.TranItemID
LEFT JOIN vEmployee e ON sc.EmployeeID = e.EmployeeID
WHERE ValTranTypeID = 3 --Sale
  AND TranDate >= ''7/30/09''
  AND TranEditedFlag is null
  AND TranVoidedID is null
  AND ReverseTranFlag is null
  AND ValPaymentTypeID = 7    --Gift Certificate
  AND mmt.DrawerActivityID IN (
		--Drawer Closed Yesterday
		SELECT DrawerActivityID 
		FROM vDrawerActivity
		WHERE CloseDateTime >= DATEADD(DD,-1,CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE(),102)))
		  AND CloseDateTime < CONVERT(DATETIME,CONVERT(VARCHAR(10),GETDATE(),102))
  )

SET ANSI_WARNINGS ON
SET NOCOUNT OFF
'

END
