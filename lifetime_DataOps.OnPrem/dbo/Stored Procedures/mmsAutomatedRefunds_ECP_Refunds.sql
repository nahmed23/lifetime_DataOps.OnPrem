
-- =============================================
-- Object:			dbo.mmsAutomatedRefunds_ECP_Refunds
-- Author:			Cully Orstad
-- Create date: 	2/12/2009 dbcr_4170 deploying 2/18/09
-- Description:		This procedure provides automated refund transactions for MMS662, Member Rlations ECP Refund Log Report
-- Modified date:	3/3/2009 GRB: added StatusID constraint in final query to fix defect (QC item not yet created);
-- Exec mmsAutomatedRefunds_ECP_Refunds '1|2|3|4|5|6', '1|2|3|4|5|6|7|8|9|10|11|12|14|15|20|21|22|30|35|36|40|50|51|52|53|126|128|131|132|133|136|137|138|139|140|141|142|143|144|146|147|148|149|150|151|152|153|154|155|156|157|158|159|160|161|162|163|164|165|166|167|168|169|170|171|172|173|174|175|176|177|178|179|180|181|182|183|184|185|186|187|188|189|190|191|192|193|194|195|196|197|198|202|215|216', '1/1/2009 11:03 AM', '2/16/2009 11:03 PM'
-- =============================================

CREATE			PROC [dbo].[mmsAutomatedRefunds_ECP_Refunds] (
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
EXEC procParseIntegerList @ClubIDs
CREATE TABLE #Clubs (ClubID VARCHAR(50))
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList


                                                 -- Create the list of 
                                                 -- eligible ECP refunds.
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
      AND  ( da.CloseDateTime >= @DrawerCloseStart
              AND
             da.CloseDateTime <= @DrawerCloseEnd  )
      AND  p.ValPaymentTypeID IN ( 9, 10, 13 )
      AND  pr.ValPaymentStatusID IN ( SELECT StatusID FROM #Status )
;


                                                 -- get any check payments 
                                                 -- that are included in 
                                                 -- the refunds.
CREATE TABLE #RefundCheckDates ( MMSTranID INT, LastCheckDate DATETIME )
INSERT INTO #RefundCheckDates ( MMSTranID, LastCheckDate )
	SELECT mtr.MMSTranID, MAX(PostDateTime) 
	FROM   vMMSTranRefund mtr
	JOIN   #RefundTranIds rti
	  ON   rti.MMSTranID = mtr.MMSTranID
	JOIN   vMMSTranRefundMMSTran mtrmt
	  ON   mtrmt.MMSTranRefundID = mtr.MMSTranRefundID
	JOIN   vMMSTran mt
	  ON   mt.MMSTranID = mtrmt.OriginalMMSTranID
	JOIN   vPayment p
	  ON   p.MMSTranID = mt.MMSTranID
    WHERE  mt.TranVoidedID IS NULL
      AND  p.ValPaymentTypeID = 2
	GROUP BY mtr.MMSTranID
;

                                                 -- get the GL Account Codes.
CREATE TABLE #RefundAccountCodes ( MMSTranID INT, AccountCode VARCHAR( 50 ) )
INSERT INTO #RefundAccountCodes
	SELECT rti.MMSTranID,
		   '1205 ' 
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


                                                 -- pull it all together
SELECT c.ClubName AS RequestingClub,
       mt.PostDateTime AS RequestDate,
       mt.MemberID,
       mtr.MMSTranID AS RefundTranID,
       rcd.LastCheckDate,
       pa.AccountNumber,
       pa.RoutingNumber,
       ABS( p.PaymentAmount ) AS Amount,
       rac.AccountCode,
       pa.Name AS AccountName,
       vpt.Description AS PaymentType,
       vps.Description AS RequestStatus,
       pr.PaymentIssuedDateTime

FROM   vMMSTranRefund mtr
JOIN   #RefundTranIds rti
  ON   rti.MMSTranID = mtr.MMSTranID
JOIN   vMMSTran mt
  ON   mt.MMSTranID = mtr.MMSTranID
JOIN   vClub c
  ON   c.ClubID = mtr.RequestingClubID
JOIN   vPayment p
  ON   p.MMSTranID = mt.MMSTranID
JOIN   vPaymentRefund pr
  ON   pr.PaymentID = p.PaymentID
JOIN   vPaymentAccount pa
  ON   pa.PaymentID = p.PaymentID
JOIN   #RefundAccountCodes rac
  ON   rac.MMSTranID = mt.MMSTranID
JOIN   vValPaymentType vpt
  ON   vpt.ValPaymentTypeID = p.ValPaymentTypeID
JOIN   vValPaymentStatus vps
  ON   vps.ValPaymentStatusID = pr.ValPaymentStatusID
LEFT JOIN #RefundCheckDates rcd
       ON rcd.MMSTranID = rti.MMSTranID

WHERE  p.ValPaymentTypeID IN ( 9, 10, 13 )
  AND  pr.ValPaymentStatusID IN ( SELECT StatusID FROM #Status )		-- 3/3/2009 GRB added


;

--
-- CLEAN UP temp tables.
--
DROP TABLE #Status
DROP TABLE #Clubs
DROP TABLE #RefundTranIds
DROP TABLE #RefundCheckDates
DROP TABLE #RefundAccountCodes

    -- Report Logging
    UPDATE HyperionReportLog
    SET EndDateTime = getdate()
    WHERE ReportLogID = @Identity

END
