
-- =============================================
-- Object:			dbo.mmsAutomatedRefunds_Check_Refunds
-- Author:			Cully Orstad
-- Create date: 	2/18/2009 dbcr_4171 deploying 2/25/09
-- Description:		This procedure provides automated refund transactions for MMS661, Member Relations Check Refund Log Report
-- Modified date:	
-- Exec mmsAutomatedRefunds_Check_Refunds '1|2|3|4|5|6', '1|2|3|4|5|6|7|8|9|10|11|12|14|15|20|21|22|30|35|36|40|50|51|52|53|126|128|131|132|133|136|137|138|139|140|141|142|143|144|146|147|148|149|150|151|152|153|154|155|156|157|158|159|160|161|162|163|164|165|166|167|168|169|170|171|172|173|174|175|176|177|178|179|180|181|182|183|184|185|186|187|188|189|190|191|192|193|194|195|196|197|198|202|215|216', '1/1/2009 11:03 AM', '2/16/2009 11:03 PM'
-- =============================================

CREATE			PROC [dbo].[mmsAutomatedRefunds_Check_Refunds] (
  @Status VARCHAR(1000),
  @ClubIDs VARCHAR(1000),
  @DrawerCloseStart DATETIME,
  @DrawerCloseEnd DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

CREATE     TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

-- Parse the Status values into a temp table
EXEC procParseIntegerList @Status
CREATE TABLE #Status (StatusID VARCHAR(50))
INSERT INTO #Status (StatusID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

-- Parse Club IDs into a temp table
CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDs = 'All'
	BEGIN
		INSERT INTO #Clubs (ClubID) SELECT ClubID FROM dbo.vClub
	END
ELSE
	BEGIN
		EXEC procParseIntegerList @ClubIDs
		INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
		TRUNCATE TABLE #tmpList
	END

                                                 -- Create the list of 
                                                 -- eligible Check refunds.
CREATE TABLE #RefundTranIds ( MMSTranID INT )
INSERT INTO #RefundTranIds ( MMSTranID )
	SELECT DISTINCT mtr.MMSTranID
	FROM   vMMSTranRefund mtr
	JOIN   #Clubs c 
	  ON   c.ClubID = mtr.RequestingClubID
	JOIN   vMMSTran mt
	  ON   mt.MMSTranID = mtr.MMSTranID
	JOIN   vDrawerActivity da
	  ON   da.DrawerActivityID = mt.DrawerActivityID
	JOIN   vPayment p
	  ON   p.MMSTranID = mt.MMSTranID
	JOIN   vPaymentRefund pr
	  ON   pr.PaymentID = p.PaymentID
    WHERE  mt.TranVoidedID IS NULL
      AND  ( ( da.CloseDateTime >= @DrawerCloseStart
                AND
               da.CloseDateTime <= @DrawerCloseEnd  )
             OR
             ( da.CloseDateTime < @DrawerCloseStart
                AND
               pr.StatusChangeDateTime >= @DrawerCloseStart
                AND
               pr.StatusChangeDateTime <= @DrawerCloseEnd ) 
           )
      AND  p.ValPaymentTypeID = 2
      AND  pr.ValPaymentStatusID IN ( SELECT StatusID FROM #Status )
;

                                                 -- get the GL Account Codes.
CREATE TABLE #RefundAccountCodes ( MMSTranID INT, AccountCode VARCHAR( 50 ) )
INSERT INTO #RefundAccountCodes
	SELECT rti.MMSTranID,
		   '1205-' 
		   + CAST(
			  ( CASE 
					WHEN mt.ReasonCodeID = 108
					THEN ( SELECT c.GLClubID
						   FROM   vMembership m
						   JOIN   vClub c
							 ON   m.ClubID = c.ClubID
						   WHERE  m.MembershipID = mt.MembershipID )
					ELSE ( SELECT c.GLClubID
						   FROM   vMMSTranRefund mtr
						   JOIN   vMMSTranRefundMMSTran mtrmt
							 ON   mtrmt.MMSTranRefundID = mtr.MMSTranRefundID
						   JOIN   vMMSTran mto
							 ON   mto.MMSTranID = mtrmt.OriginalMMSTranID
						   JOIN   vClub c
							 ON   c.ClubID = mto.ClubID
						   WHERE  mtr.MMSTranID = rti.MMSTranID
						 )
				END ) 
			 AS VARCHAR(5) ) AS AccountCode
	FROM   #RefundTranIds rti
	JOIN   vMMSTran mt
	  ON   rti.MMSTranID = mt.MMSTranID
;

                                                 -- pull it all together.
SELECT c.ClubName                                AS RequestingClub,
       mt.PostDateTime							 AS RequestDate,
       CASE
			WHEN m.LastName = 'House Account'
            THEN 'Nonmember'
            ELSE CAST( mt.MemberID AS VARCHAR( 50 ) )
       END
                                                 AS MemberID,
       mt.MMSTranID                              AS RefundTranID,
       prc.LastName + ', ' + prc.FirstName       AS PayeeName,
       prc.AddressLine1 + ' ' + prc.AddressLine2 AS MailingAddressStreetAddress,
       prc.City                                  AS MailingAddressCity,
       vs.Abbreviation                           AS MailingAddressState,
       prc.Zip                                   AS MailingAddressPostalCode,
       vc.Abbreviation                           AS MailingAddressCountry,
       ABS( p.PaymentAmount )                    AS CheckAmount,
       rac.AccountCode,
       pr.ReferenceNumber,
       vps.Description                           AS RequestStatus,
       pr.PaymentIssuedDateTime                  AS IssuedDate

FROM   #RefundTranIds rti

JOIN   vMMSTranRefund mtr
  ON   mtr.MMSTranID = rti.MMSTranID
JOIN   vMMSTran mt
  ON   mt.MMSTranID = rti.MMSTranID
JOIN   vClub c
  ON   c.ClubID = mtr.RequestingClubID
JOIN   vMember m
  ON   m.MemberID = mt.MemberID
JOIN   vPayment p
  ON   p.MMSTranID = mt.MMSTranID
JOIN   vPaymentRefund pr
  ON   pr.PaymentID = p.PaymentID
JOIN   vPaymentRefundContact prc
  ON   prc.PaymentRefundID = pr.PaymentRefundID
JOIN   vValState vs
  ON   vs.ValStateID = prc.ValStateID
JOIN   vValCountry vc
  ON   vc.ValCountryID = prc.ValCountryID
JOIN   #RefundAccountCodes rac
  ON   rac.MMSTranID = mt.MMSTranID
JOIN   vValPaymentStatus vps
  ON   vps.ValPaymentStatusID = pr.ValPaymentStatusID

WHERE  p.ValPaymentTypeID = 2
  AND  pr.ValPaymentStatusID IN ( SELECT StatusID FROM #Status )
;

DROP TABLE #Status
DROP TABLE #Clubs
DROP TABLE #RefundTranIds
DROP TABLE #RefundAccountCodes

    -- Report Logging
    UPDATE HyperionReportLog
    SET EndDateTime = getdate()
    WHERE ReportLogID = @Identity

END
