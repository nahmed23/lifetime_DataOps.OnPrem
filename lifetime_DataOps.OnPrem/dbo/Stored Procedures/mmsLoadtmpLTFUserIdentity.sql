

-- This procedure inserts user identity data for members

CREATE PROCEDURE [dbo].[mmsLoadtmpLTFUserIdentity]
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

     DELETE FROM tmpLTFUserIdentity;

     INSERT INTO tmpLTFUserIdentity
     SELECT lui.lui_identity_status_from_datetime AS Date, 
	        m.member_id, 
	        CAST(lui.lui_identity_status AS VARCHAR(25)) AS Status
       FROM LTFEB_Subscriber..LTFUserIdentity lui WITH (NOLOCK)
       JOIN LTFEB_Subscriber..vLTFMember m WITH (NOLOCK)
         ON m.party_id = lui.party_id

     SELECT @RowsProcessed = COUNT(*) FROM tmpLTFUserIdentity
     SELECT @Description = 'Number of Members in tmpLTFUserIdentity'
END

