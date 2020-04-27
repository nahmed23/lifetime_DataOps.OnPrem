
CREATE PROC [dbo].[proc_NewMembershipsWithPaymentType] (
   @PaymentTypeDescriptionList VARCHAR(8000),
   @PromoStartDate VARCHAR(50)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT    ON


/*Set-up variable to include the current date in the name */
DECLARE @subjectline VARCHAR (250)
SET @subjectline = 'LTFDW PROD -  myLTBuck$ Bonus Buck$ Qualifying Memberships for ' + Convert(Varchar,GetDate()-1,110)

DECLARE @BodyText VARCHAR(250)
SET @BodyText = 'Attached are yesterday''s qualifying memberships for the Bonus Buck$ promotion.  
File can also be found on the network at: \\Ltfinc.net\ltfshare\Corp\Operations\Public_data'

DECLARE @FileName VARCHAR(100)
SET @FileName = 'myLTBuck$_BonusBuck$_QualifyingMemberships_'+convert(varchar,getdate(),110)+'.xls'

DECLARE @Recipients VARCHAR(1000)
SET @Recipients = 'MNeuman@lifetimefitness.com;mweber@egroupnet.com'
--SET @Recipients = 'bdahlman@lifetimefitness.com'

DECLARE @sql NVARCHAR(max)
SET @sql = '
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(50))
EXEC procParseStringList '''+@PaymentTypeDescriptionList+'''


SELECT StringField PaymentType, 
       CASE WHEN StringField = ''Discover'' THEN 100
            WHEN StringField = ''Visa'' THEN 100
            WHEN StringField = ''Flex Reactivation'' THEN 100
            ELSE 0 END BuckAmount
INTO #PromoTable
FROM #tmpList

DECLARE @StartDate DATETIME,
        @EndDate DATETIME
SET @EndDate = Convert(DateTime,Convert(Varchar,GetDate(),101),101)
SET @StartDate = @EndDate - 1

SELECT DISTINCT MA.RowID MembershipID
  INTO #AlreadyReceivedFlexPromo
  FROM vMembershipAudit MA
  JOIN vMembershipType OldMT
    ON MA.OldValue = OldMT.MembershipTypeID
  JOIN vMembershipType NewMT
    ON MA.NewValue = NewMT.MembershipTypeID
  JOIN vMember M
    ON MA.RowID = M.MembershipID
  JOIN vValMemberType VMT 
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
 WHERE MA.ColumnName = ''MembershipTypeID''
   AND MA.ModifiedDateTime >= Convert(Datetime,'''+@PromoStartDate+''')
   AND MA.ModifiedDateTime < @StartDate
   AND OldMT.MembershipTypeID in (4032,6757,5780,7268,4351,4033,6758,4035,7269,4495,4034,7270,5349)
   AND NewMT.ValCheckInGroupID <> 0
   AND VMT.Description = ''Primary''

SELECT M.FirstName,
       M.LastName,
       Cast(M.MemberID as Varchar(11)) MemberID,
       M.EmailAddress,
       Cast(#PromoTable.BuckAmount as Varchar(11)) BuckAmount,
       #PromoTable.PaymentType Reference
  FROM vMembership MS
  JOIN vEFTAccount EA 
    ON MS.MembershipID = EA.MembershipID
  JOIN vCreditCardAccount CCA 
    ON EA.CreditCardAccountID = CCA.CreditCardAccountID
  JOIN vValPaymentType PT 
    ON CCA.ValPaymentTypeID = PT.ValPaymentTypeID
  JOIN vMember M 
    ON MS.MembershipID = M.MembershipID
  JOIN vValMemberType VMT 
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #PromoTable 
    ON PT.Description = #PromoTable.PaymentType
 WHERE MS.CreatedDateTime >= @StartDate
   AND MS.CreatedDateTime < @EndDate
   AND VMT.Description = ''Primary''
UNION
SELECT DISTINCT M.FirstName,
                M.LastName,
                Cast(M.memberID as Varchar(11)) MemberID,
                M.EmailAddress,
                Cast(100 as Varchar(11)) BuckAmount,
                ''Flex Reactivation'' Reference
  FROM vMembershipAudit MA
  JOIN vMembershipType OldMT
    ON MA.OldValue = OldMT.MembershipTypeID
  JOIN vMembershipType NewMT
    ON MA.NewValue = NewMT.MembershipTypeID
  JOIN vMember M
    ON MA.RowID = M.MembershipID
  JOIN vValMemberType VMT 
    ON M.ValMemberTypeID = VMT.ValMemberTypeID
  JOIN #PromoTable
    ON #PromoTable.PaymentType = ''Flex Reactivation''
  LEFT JOIN #AlreadyReceivedFlexPromo
    ON MA.RowID = #AlreadyReceivedFlexPromo.MembershipID
 WHERE MA.ColumnName = ''MembershipTypeID''
   AND MA.ModifiedDateTime >= @StartDate
   AND MA.ModifiedDateTime < @EndDate
   AND OldMT.MembershipTypeID in (4032,6757,5780,7268,4351,4033,6758,4035,7269,4495,4034,7270,5349)
   AND NewMT.ValCheckInGroupID <> 0
   AND VMT.Description = ''Primary''
   AND #AlreadyReceivedFlexPromo.MembershipID IS NULL
UNION
SELECT ''FirstName'',''LastName'',''MemberID'',''EmailAddress'',''BuckAmount'',''Reference''
ORDER BY BuckAmount DESC

drop table #tmpList
drop table #PromoTable  
drop table #AlreadyReceivedFlexPromo
'

EXEC msdb.dbo.sp_send_dbmail 
					 @profile_name = 'sqlsrvcacct'
                    ,@recipients = @Recipients
					,@copy_recipients = 'ISDataWarehouseSupport@lifetimefitness.com'
                    ,@subject=@subjectline
                    ,@body = @BodyText
					,@attach_query_result_as_file = 1
					,@query_attachment_filename = @FileName
					,@exclude_query_output = 1
					,@query_result_no_padding = 1
				    ,@query_result_separator = '	'
				    ,@query_result_header = 0
                    ,@execute_query_database = 'Report_MMS'
					,@query=@sql


EXEC(@sql)

END
