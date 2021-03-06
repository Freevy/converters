/* ATTENTION: You don't need to run or use this file!  The convert.php script does everything for you! */

/******************************************************************************/
---~ name: "vBulletin 3.0 - 3.4"
/******************************************************************************/
---~ version: "SMF 2.0"
---~ settings: "/admin/config.php", "/includes/config.php"
---~ from_prefix: "`$dbname`.$tableprefix"
---~ table_test: "{$from_prefix}user"

/******************************************************************************/
--- Converting members...
/******************************************************************************/

TRUNCATE {$to_prefix}members;

---* {$to_prefix}members
SELECT
	u.userid AS id_member, SUBSTRING(u.username, 1, 80) AS member_name,
	SUBSTRING(u.username, 1, 255) AS real_name,
	SUBSTRING(u.password, 1, 64) AS passwd,
	SUBSTRING(u.email, 1, 255) AS email_address,
	SUBSTRING(u.homepage, 1, 255) AS website_title,
	SUBSTRING(u.homepage, 1, 255) AS website_url,
	SUBSTRING(u.icq, 1, 255) AS icq, SUBSTRING(u.aim, 1, 16) AS aim,
	SUBSTRING(u.yahoo, 1, 32) AS yim,
	SUBSTRING(IF(u.customtitle, u.usertitle, ''), 1, 255) AS usertitle,
	u.lastvisit AS last_login, u.joindate AS date_registered, u.posts,
	u.reputation AS karma_good, u.birthday_search AS birthdate,
	SUBSTRING(u.ipaddress, 1, 255) AS member_ip,
	SUBSTRING(u.ipaddress, 1, 255) AS member_ip2,
	SUBSTRING(u.msn, 1, 255) AS msn,
	CASE u.usergroupid WHEN 6 THEN 1 WHEN 5 THEN 2 WHEN 7 THEN 2 ELSE 0 END AS id_group,
	SUBSTRING(u.salt, 1, 5) AS password_salt,
	SUBSTRING(ut.signature, 1, 65534) AS signature, '' AS lngfile,
	'' AS buddy_list, '' AS pm_ignore_list, '' AS message_labels,
	'' AS personal_text, '' AS time_format, '' AS avatar, '' AS secret_question,
	'' AS secret_answer, '' AS validation_code, '' AS additional_groups,
	'' AS smiley_set
FROM {$from_prefix}user AS u
	LEFT JOIN {$from_prefix}usertextfield AS ut ON (ut.userid = u.userid)
WHERE u.userid != 0;
---*

/******************************************************************************/
--- Converting categories...
/******************************************************************************/

TRUNCATE {$to_prefix}categories;

---* {$to_prefix}categories
SELECT
	forumid AS id_cat, SUBSTRING(title, 1, 255) AS name,
	displayorder AS cat_order
FROM {$from_prefix}forum
WHERE parentid = -1;
---*

/******************************************************************************/
--- Converting boards...
/******************************************************************************/

TRUNCATE {$to_prefix}boards;
DELETE FROM {$to_prefix}board_permissions
WHERE id_profile > 4;

/* The converter will set id_cat for us based on id_parent being wrong. */
---* {$to_prefix}boards
SELECT
	forumid AS id_board, SUBSTRING(title, 1, 255) AS name,
	SUBSTRING(description, 1, 65534) AS description,
	displayorder AS board_order, replycount AS num_posts,
	threadcount AS num_topics, parentid AS id_parent, '-1,0' AS member_groups
FROM {$from_prefix}forum
WHERE parentid != -1;
---*

/******************************************************************************/
--- Converting topics...
/******************************************************************************/

TRUNCATE {$to_prefix}topics;
TRUNCATE {$to_prefix}log_topics;
TRUNCATE {$to_prefix}log_boards;
TRUNCATE {$to_prefix}log_mark_read;

---* {$to_prefix}topics
SELECT
	t.threadid AS id_topic, t.forumid AS id_board, t.sticky AS is_sticky,
	t.pollid AS id_poll, t.views AS num_views, t.postuserid AS id_member_started,
	ul.userid AS id_member_updated, t.replycount AS num_replies,
	IF(t.open, 0, 1) AS locked, MIN(p.postid) AS id_first_msg,
	MAX(p.postid) AS id_last_msg
FROM {$from_prefix}thread AS t
	INNER JOIN {$from_prefix}post AS p ON (p.threadid = t.threadid)
	LEFT JOIN {$from_prefix}user AS ul ON (ul.username = t.lastposter)
GROUP BY t.threadid
HAVING id_first_msg != 0
	AND id_last_msg != 0;
---*

/******************************************************************************/
--- Converting posts (this may take some time)...
/******************************************************************************/

TRUNCATE {$to_prefix}messages;
TRUNCATE {$to_prefix}attachments;

---* {$to_prefix}messages 200
---{
$row['body'] = preg_replace('~\[(quote)=([^\]]+)\]~i', '[$1=&quot;$2&quot;]', strtr($row['body'], array('"' => '&quot;')));
$row['body'] = substr(preg_replace('~\[(url|email)=&quot;(.+?)&quot;\]~i', '[$1=$2]', $row['body']), 0, 65534);
---}
SELECT
	p.postid AS id_msg, p.threadid AS id_topic, p.dateline AS poster_time,
	p.userid AS id_member,
	SUBSTRING(IF(p.title = '', t.title, p.title), 1, 255) AS subject,
	SUBSTRING(p.username, 1, 255) AS poster_name,
	SUBSTRING(p.ipaddress, 1, 255) AS poster_ip, t.forumid AS id_board,
	p.allowsmilie AS smileys_enabled,
	REPLACE(p.pagetext, '<br>', '<br />') AS body, '' AS poster_email,
	'' AS modified_name, 'xx' AS icon
FROM {$from_prefix}post AS p
	INNER JOIN {$from_prefix}thread AS t ON (t.threadid = p.threadid);
---*

---* {$to_prefix}messages (update id_msg)
SELECT postid AS id_msg, username AS modified_name, dateline AS modified_time
FROM {$from_prefix}editlog
ORDER BY dateline;
---*

/******************************************************************************/
--- Converting polls...
/******************************************************************************/

TRUNCATE {$to_prefix}polls;
TRUNCATE {$to_prefix}poll_choices;
TRUNCATE {$to_prefix}log_polls;

---* {$to_prefix}polls
SELECT
	p.pollid AS id_poll, SUBSTRING(p.question, 1, 255) AS question,
	IF(p.active = 0, 1, 0) AS voting_locked, p.multiple AS max_votes,
	SUBSTRING(IFNULL(t.postusername, 'Guest'), 1, 255) AS poster_name,
	IF(p.timeout = 0, 0, p.dateline + p.timeout * 86400) AS expire_time,
	t.postuserid AS id_member
FROM {$from_prefix}poll AS p
	LEFT JOIN {$from_prefix}thread AS t ON (t.pollid = p.pollid);
---*

/******************************************************************************/
--- Converting poll options...
/******************************************************************************/

---* {$to_prefix}poll_choices
---{
$no_add = true;
$keys = array('id_poll', 'id_choice', 'label', 'votes');

$options = explode('|||', $row['options']);
$votes = explode('|||', $row['votes']);
$id_poll = $row['id_poll'];
for ($i = 0, $n = count($options); $i < $n; $i++)
{
	$rows[] = array(
		'id_poll' => $id_poll,
		'id_choice' => ($i + 1),
		'label' => substr(addslashes($options[$i]), 1, 255),
		'votes' => @$votes[$i],
	);
}
---}
SELECT pollid AS id_poll, options, votes
FROM {$from_prefix}poll;
---*

/******************************************************************************/
--- Converting poll votes...
/******************************************************************************/

---* {$to_prefix}log_polls
SELECT pollid AS id_poll, userid AS id_member, voteoption AS id_choice
FROM {$from_prefix}pollvote;
---*

/******************************************************************************/
--- Converting personal messages (step 1)...
/******************************************************************************/

TRUNCATE {$to_prefix}personal_messages;

---* {$to_prefix}personal_messages
---{
$row['body'] = preg_replace('~\[(quote)=([^\]]+)\]~i', '[$1=&quot;$2&quot;]', $row['body']);
---}
SELECT
	pm.pmid AS id_pm, pmt.fromuserid AS id_member_from, pmt.dateline AS msgtime,
	SUBSTRING(pmt.fromusername, 1, 255) AS from_name,
	SUBSTRING(pmt.title, 1, 255) AS subject,
	SUBSTRING(REPLACE(pmt.message, '<br>', '<br />'), 1, 65534) AS body
FROM {$from_prefix}pm AS pm
	INNER JOIN {$from_prefix}pmtext AS pmt ON (pmt.pmtextid = pm.pmtextid)
WHERE pm.folderid != -1;
---*

/******************************************************************************/
--- Converting personal messages (step 2)...
/******************************************************************************/

TRUNCATE {$to_prefix}pm_recipients;

---* {$to_prefix}pm_recipients
SELECT
	pm.pmid AS id_pm, pm.touserid AS id_member, pm.readtime != 0 AS is_read,
	'-1' AS labels
FROM {$from_prefix}pmreceipt AS pm;
---*

/******************************************************************************/
--- Converting topic notifications...
/******************************************************************************/

TRUNCATE {$to_prefix}log_notify;

---* {$to_prefix}log_notify
SELECT userid AS id_member, threadid AS id_topic
FROM {$from_prefix}subscribethread;
---*

/******************************************************************************/
--- Converting board notifications...
/******************************************************************************/

---* {$to_prefix}log_notify
SELECT userid AS id_member, forumid AS id_board
FROM {$from_prefix}subscribeforum;
---*

/******************************************************************************/
--- Converting smileys...
/******************************************************************************/

UPDATE {$to_prefix}smileys
SET hidden = 1;

---{
$specificSmileys = array(
	':cool:' => 'cool',
	':(' => 'sad',
	':confused:' => 'huh',
	':mad:' => 'angry',
	':rolleyes:' => 'rolleyes',
	':eek:' => 'shocked',
	':p' => 'tongue',
	':o' => 'embarrassed',
	';)' => 'wink',
	':D' => 'grin',
	':)' => 'smiley',
);

$request = convert_query("
	SELECT MAX(smiley_order)
	FROM {$to_prefix}smileys");
list ($count) = convert_fetch_row($request);
convert_free_result($request);

$request = convert_query("
	SELECT code
	FROM {$to_prefix}smileys");
$currentCodes = array();
while ($row = convert_fetch_assoc($request))
	$currentCodes[] = $row['code'];
convert_free_result($request);

$rows = array();
foreach ($specificSmileys as $code => $name)
{
	if (in_array($code, $currentCodes))
		continue;

	$count++;
	$rows[] = array($code, $name . '.gif, $name, $count);
}

if (!empty($rows))
	convert_insert('smileys', array('variable', 'value'), $rows, 'replace');
---}

/******************************************************************************/
--- Converting attachments...
/******************************************************************************/

---* {$to_prefix}attachments
---{
$no_add = true;

if (!isset($vb_settings))
{
	$result = convert_query("
		SELECT varname, value
		FROM {$from_prefix}setting
		WHERE varname IN ('attachfile', 'attachpath', 'usefileavatar', 'avatarpath')
		LIMIT 4");
	$vb_settings = array();
	while ($row2 = convert_fetch_assoc($result))
	{
		if (substr($row2['value'], 0, 2) == './')
			$row2['value'] = $_POST['path_from'] . substr($row2['value'], 1);
		$vb_settings[$row2['varname']] = $row2['value'];
	}
	convert_free_result($result);
}

$file_hash = getAttachmentFilename($row['filename'], $id_attach, null, true);
$physical_filename = $id_attach . '_' . $file_hash;

if (strlen($physical_filename) > 255)
	return;

if (empty($vb_settings['attachfile']))
{
	$fp = @fopen($attachmentUploadDir . '/' . $physical_filename, 'wb');
	if (!$fp)
		return;

	fwrite($fp, $row['filedata']);
	fclose($fp);
}
elseif ($vb_settings['attachfile'] == 1)
{
	if (!copy($vb_settings['attachpath'] . '/' . $row['userid'] . '/' . $row['attachmentid'] . '.attach', $attachmentUploadDir . '/' . $physical_filename))
		return;
}
elseif ($vb_settings['attachfile'] == 2)
{
	if (!copy($vb_settings['attachpath'] . '/' . chunk_split($row['userid'], 1, '/') . $row['attachmentid'] . '.attach', $attachmentUploadDir . '/' . $physical_filename))
		return;
}

$rows[] = array(
	'id_attach' => $id_attach,
	'size' => filesize($attachmentUploadDir . '/' . $physical_filename),
	'filename' => $row['filename'],
	'file_hash' => $file_hash,
	'id_msg' => $row['id_msg'],
	'downloads' => $row['downloads'],
);
$id_attach++;
---}
SELECT
	postid AS id_msg, counter AS downloads, filename, filedata, userid,
	attachmentid
FROM {$from_prefix}attachment;
---*

/******************************************************************************/
--- Converting avatars...
/******************************************************************************/

---* {$to_prefix}attachments
---{
$no_add = true;

if (!isset($vb_settings))
{
	$result = convert_query("
		SELECT varname, value
		FROM {$from_prefix}setting
		WHERE varname IN ('attachfile', 'attachpath', 'usefileavatar', 'avatarpath')
		LIMIT 4");
	$vb_settings = array();
	while ($row2 = convert_fetch_assoc($result))
	{
		if (substr($row2['value'], 0, 2) == './')
			$row2['value'] = $_POST['path_from'] . substr($row2['value'], 1);
		$vb_settings[$row2['varname']] = $row2['value'];
	}
	convert_free_result($result);
}

$file_hash = getAttachmentFilename($row['filename'], $id_attach, null, true);
$physical_filename = $id_attach . '_' . $file_hash;

if (strlen($physical_filename) > 255)
	return;
if (empty($vb_settings['usefileavatar']))
{
	$fp = @fopen($attachmentUploadDir . '/' . $physical_filename, 'wb');
	if (!$fp)
		return;

	fwrite($fp, $row['avatardata']);
	fclose($fp);
}
elseif (!copy($vb_settings['avatarpath'] . '/avatar' . $row['id_member'] . '_' . $row['avatarrevision'] . '.gif', $attachmentUploadDir . '/' . $physical_filename))
	return;

$rows[] = array(
	'id_attach' => $id_attach,
	'size' => filesize($attachmentUploadDir . '/' . $physical_filename),
	'filename' => $row['filename'],
	'file_hash' => $file_hash,
	'id_member' => $row['id_member'],
);
$id_attach++;
---}
SELECT ca.userid AS id_member, ca.avatardata, ca.filename, u.avatarrevision
FROM {$from_prefix}customavatar AS ca
	INNER JOIN {$from_prefix}user AS u ON (u.userid = ca.userid);
---*