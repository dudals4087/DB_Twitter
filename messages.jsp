<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.util.UUID, java.net.URLEncoder, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String currentInitial = "G";
    if (currentUser != null && currentUser.length() > 0) {
        currentInitial = currentUser.substring(0,1).toUpperCase();
    }

    if (currentUser == null) {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
        response.sendRedirect("login.jsp");
        return;
    }

    String infoMsg = null;
    String errorMsg = null;
    String selectedPeer = request.getParameter("peer");
    if (selectedPeer != null) selectedPeer = selectedPeer.trim();

    // --- [1] 메시지 전송 처리 (POST) ---
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String mode = request.getParameter("mode");
        if ("send".equals(mode)) {
            String peer = request.getParameter("peer");
            String content = request.getParameter("content");
            if (peer == null) peer = "";
            if (content == null) content = "";
            peer = peer.trim();
            content = content.trim();
            selectedPeer = peer;

            if (peer.isEmpty()) {
                infoMsg = "대화할 사용자를 선택해 주세요";
            } else if (peer.equals(currentUser)) {
                infoMsg = "자기 자신에게는 메시지를 보낼 수 없습니다";
            } else if (content.isEmpty()) {
                infoMsg = "보낼 메시지를 입력해 주세요";
            } else {
                try {
                    // [중요] 내가 상대를 팔로우 중인지 확인 (그래야 메시지 전송 가능)
                    boolean canChat = false;
                    // followings 테이블: user_id(상대), follower_id(나)
                    String chkSql = "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
                    try (PreparedStatement ps = con.prepareStatement(chkSql)) {
                        ps.setString(1, peer);        // 상대방
                        ps.setString(2, currentUser); // 나
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) canChat = true;
                        }
                    }

                    // 예외: 이미 대화 내역이 있다면 팔로우 끊겨도 답장은 가능하게 할 수도 있음 (여기선 팔로우 필수 유지)
                    // 만약 '맞팔'이어야만 한다면 쿼리를 수정해야 하지만, '내가 팔로우하면 보냄'이 조건이므로 유지.
                    
                    if (!canChat) {
                        // 혹시 이미 대화가 오갔던 사이라면 허용할 수도 있음 (선택사항). 일단은 엄격하게 체크.
                        // 단, 기존 대화가 있으면 리스트엔 뜨지만 전송은 막힐 수 있음.
                        // 편의를 위해 "대화 기록이 있으면 전송 허용" 로직을 추가할 수도 있습니다.
                        String msgExist = "SELECT 1 FROM message WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) LIMIT 1";
                        try(PreparedStatement ps2 = con.prepareStatement(msgExist)){
                            ps2.setString(1, currentUser); ps2.setString(2, peer);
                            ps2.setString(3, peer); ps2.setString(4, currentUser);
                            try(ResultSet rs2 = ps2.executeQuery()){ if(rs2.next()) canChat = true; }
                        }
                    }

                    if (!canChat) {
                        infoMsg = "메시지를 보내려면 먼저 해당 유저를 팔로우해야 합니다.";
                    } else {
                        String mid = "m" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                        String insSql = "INSERT INTO message (m_id, sender, receiver, content, created_at) VALUES (?, ?, ?, ?, NOW())";
                        try (PreparedStatement ps = con.prepareStatement(insSql)) {
                            ps.setString(1, mid);
                            ps.setString(2, currentUser);
                            ps.setString(3, peer);
                            ps.setString(4, content);
                            ps.executeUpdate();
                        }
                        // 전송 후 리다이렉트
                        response.sendRedirect("messages.jsp?peer=" + URLEncoder.encode(peer, "UTF-8"));
                        return;
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    errorMsg = "메시지를 보내는 중 오류가 발생했어요";
                }
            }
        }
    }

    // --- [2] 왼쪽 목록 가져오기 로직 (수정됨) ---
    List<Map<String,String>> userList = new ArrayList<Map<String,String>>();
    Set<String> addedIds = new HashSet<String>();
    
    // 2-1. [수정] 내가 팔로우한 사람 목록 (Followings)
    // 이전 코드: WHERE f.user_id = ? (나를 따르는 사람) -> 잘못됨
    // 수정 코드: WHERE f.follower_id = ? (내가 따르는 사람) -> 정답
    try {
        String uSql = "SELECT u.user_id, u.status_message, u.paid, u.profile_img " +
                      "FROM followings f " +
                      "JOIN users u ON u.user_id = f.user_id " + // 내가 팔로우한 사람의 정보
                      "WHERE f.follower_id = ? " + // 기준은 나(Follower)
                      "ORDER BY u.user_id";
        
        try (PreparedStatement ps = con.prepareStatement(uSql)) {
            ps.setString(1, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String uid = rs.getString("user_id");
                    Map<String,String> row = new HashMap<String,String>();
                    row.put("user_id", uid);
                    row.put("status_message", rs.getString("status_message"));
                    row.put("paid", rs.getString("paid"));
                    row.put("profile_img", rs.getString("profile_img"));
                    row.put("rel", "follow");
                    userList.add(row);
                    if (uid != null) addedIds.add(uid);
                }
            }
        }
    } catch (Exception e) { e.printStackTrace(); }

    // 2-2. 대화 기록이 있는 사람 목록 (맞팔 아니어도 대화했으면 표시)
    try {
        String convSql = "SELECT DISTINCT CASE WHEN sender = ? THEN receiver ELSE sender END AS peer_id FROM message WHERE sender = ? OR receiver = ?";
        try (PreparedStatement ps = con.prepareStatement(convSql)) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            ps.setString(3, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String peerId = rs.getString("peer_id");
                    if (peerId == null || peerId.equals(currentUser)) continue;
                    if (addedIds.contains(peerId)) continue; // 이미 리스트에 있으면 패스
                    
                    String infoSql = "SELECT user_id, status_message, paid, profile_img FROM users WHERE user_id = ?";
                    try (PreparedStatement ps2 = con.prepareStatement(infoSql)) {
                        ps2.setString(1, peerId);
                        try (ResultSet rs2 = ps2.executeQuery()) {
                            if (rs2.next()) {
                                Map<String,String> row = new HashMap<String,String>();
                                row.put("user_id", rs2.getString("user_id"));
                                row.put("status_message", rs2.getString("status_message"));
                                row.put("paid", rs2.getString("paid"));
                                row.put("profile_img", rs2.getString("profile_img"));
                                row.put("rel", "msg");
                                userList.add(row);
                                addedIds.add(peerId);
                            }
                        }
                    }
                }
            }
        }
    } catch (Exception e) { e.printStackTrace(); }

    // --- [3] 선택된 상대 정보 조회 ---
    String peerStatus = null;
    String peerPaid = null;
    String peerProfileImg = null;
    boolean peerExists = false;

    if (selectedPeer != null && !selectedPeer.isEmpty()) {
        try {
            // 유저 정보 존재 확인
            String pSql = "SELECT status_message, paid, profile_img FROM users WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(pSql)) {
                ps.setString(1, selectedPeer);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        peerExists = true; // 유저는 존재함
                        peerStatus = rs.getString("status_message");
                        peerPaid = rs.getString("paid");
                        peerProfileImg = rs.getString("profile_img");
                    }
                }
            }
        } catch (Exception e) { e.printStackTrace(); }
    }

    // --- [4] 대화 내용 조회 ---
    List<Map<String,Object>> chatList = new ArrayList<Map<String,Object>>();
    if (peerExists) {
        try {
            String mSql = "SELECT m_id, sender, receiver, content, created_at FROM message WHERE (sender=? AND receiver=?) OR (sender=? AND receiver=?) ORDER BY created_at ASC";
            try (PreparedStatement ps = con.prepareStatement(mSql)) {
                ps.setString(1, currentUser); ps.setString(2, selectedPeer);
                ps.setString(3, selectedPeer); ps.setString(4, currentUser);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        Map<String,Object> row = new HashMap<String,Object>();
                        String sender = rs.getString("sender");
                        row.put("sender", sender);
                        row.put("receiver", rs.getString("receiver"));
                        row.put("content", rs.getString("content"));
                        row.put("isMe", currentUser.equals(sender));
                        chatList.add(row);
                    }
                }
            }
        } catch (Exception e) { e.printStackTrace(); }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>메시지 / Twitter</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .avatar-sm-img {
            width: 40px; height: 40px; 
            border-radius: 50%; 
            object-fit: cover; 
            border: 1px solid #cfd9de;
        }
    </style>
</head>
<body style="overflow: hidden;"> 
<div class="app-shell">
    
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">메시지</div>
        </div>
        <div class="app-header-right">
            <a href="main.jsp" class="icon-btn"><i class="fa-solid fa-house"></i></a>
        </div>
    </header>

    <div class="messages-layout">
        
        <div class="messages-left">
            <div class="list-header">대화 상대 선택</div>
            <div class="user-list">
                <% if (userList.isEmpty()) { %>
                    <div style="padding:10px;" class="helper-text">
                        팔로우한 사용자가 없습니다.
                    </div>
                <% } else {
                    for (Map<String,String> u : userList) {
                        String uid = u.get("user_id");
                        String upaid = u.get("paid");
                        String uImg = u.get("profile_img");
                        boolean active = (selectedPeer != null && selectedPeer.equals(uid));
                %>
                    <a href="messages.jsp?peer=<%= uid %>" class="user-item <%= active ? "active" : "" %>" style="text-decoration:none; color:inherit; display:flex;">
                        <div style="margin-right:10px;">
                            <% if(uImg != null && !uImg.isEmpty()) { %>
                                <img src="uploads/<%= uImg %>" class="avatar-sm-img">
                            <% } else { %>
                                <div class="avatar-sm">
                                    <%= (uid != null && uid.length() > 0) ? uid.substring(0,1).toUpperCase() : "U" %>
                                </div>
                            <% } %>
                        </div>

                        <div style="flex:1;">
                            <div class="user-name-row">
                                <%= uid %>
                                <% if ("T".equals(upaid)) { %><span class="badge-check">✓</span><% } %>
                            </div>
                            <div class="user-status" style="font-size:13px; color:#536471;">
                                <%= u.get("status_message") != null ? u.get("status_message") : "" %>
                            </div>
                        </div>
                    </a>
                <%  }
                } %>
            </div>
        </div>

        <div class="messages-right">
            <% if (selectedPeer == null || selectedPeer.isEmpty()) { %>
                <div class="empty-state" style="margin-top:20%;">
                    <div class="empty-icon"><i class="fa-regular fa-paper-plane"></i></div>
                    <h3>메시지를 보낼 상대를 선택하세요</h3>
                </div>
            <% } else if (!peerExists) { %>
                <div class="empty-state" style="margin-top:20%;">
                    <h3>사용자를 찾을 수 없습니다</h3>
                </div>
            <% } else { 
                boolean peerIsPaid = "T".equals(peerPaid);
            %>
                <div class="chat-header">
                    <div style="margin-right:10px; display:flex; align-items:center;">
                         <% if(peerProfileImg != null && !peerProfileImg.isEmpty()) { %>
                            <img src="uploads/<%= peerProfileImg %>" class="avatar-sm-img" style="width:32px; height:32px;">
                        <% } else { %>
                            <div class="avatar-sm" style="width:32px; height:32px; font-size:14px; line-height:32px;">
                                <%= selectedPeer.substring(0,1).toUpperCase() %>
                            </div>
                        <% } %>
                    </div>

                    <div>
                        <div class="user-name-row" style="font-size: 16px;">
                            <%= selectedPeer %>
                            <% if (peerIsPaid) { %><span class="badge-check">✓</span><% } %>
                        </div>
                        <div style="font-size:12px; color:#536471;">
                            <%= (peerStatus != null) ? peerStatus : "" %>
                        </div>
                    </div>
                </div>

                <div class="chat-body" id="chatBox">
                    <% if (chatList.isEmpty()) { %>
                        <div class="helper-text" style="text-align:center; margin-top:20px;">
                            첫 메시지를 보내보세요!
                        </div>
                    <% } else {
                        for (Map<String,Object> m : chatList) {
                            boolean isMe = (Boolean) m.get("isMe");
                            String content = (String) m.get("content");
                    %>
                        <div class="chat-row <%= isMe ? "me" : "other" %>">
                            <div class="chat-bubble <%= isMe ? "me" : "other" %>">
                                <%= (content == null ? "" : content) %>
                            </div>
                        </div>
                    <%  }
                    } %>
                </div>

                <div class="chat-input-bar">
                    <% if (infoMsg != null) { %>
                        <div style="color:red; font-size:12px; margin-bottom:5px; text-align:center;"><%= infoMsg %></div>
                    <% } %>

                    <form method="post" action="messages.jsp" class="chat-input-form">
                        <input type="hidden" name="mode" value="send">
                        <input type="hidden" name="peer" value="<%= selectedPeer %>">
                        
                        <input type="text" name="content" class="chat-input-text" 
                               placeholder="새 쪽지 보내기..." required autocomplete="off">
                        
                        <button type="submit" class="btn-send">
                            <i class="fa-solid fa-paper-plane"></i>
                        </button>
                    </form>
                </div>

                <script>
                    window.onload = function() {
                        var chatBox = document.getElementById("chatBox");
                        if(chatBox) chatBox.scrollTop = chatBox.scrollHeight;
                    }
                </script>
            <% } %>
        </div>

    </div>
</div>
</body>
</html>
<%
    if (con != null) { try { con.close(); } catch (Exception ignore) {} }
%>