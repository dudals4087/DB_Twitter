<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // 세션 정보
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String currentInitial = "G";
    if (currentUser != null && currentUser.length() > 0) {
        currentInitial = currentUser.substring(0,1).toUpperCase();
    }

    // 로그인 안 되어 있으면 로그인 페이지로
    if (currentUser == null) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String initials = currentUser.substring(0, 1).toUpperCase();

    String infoMsg = null;
    String errorMsg = null;

    // 선택된 대화 상대
    String selectedPeer = request.getParameter("peer");
    if (selectedPeer != null) selectedPeer = selectedPeer.trim();

    // 메시지 전송 처리
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
                    // 보낼 수 있는 상대인지  내가 팔로우한 사람만
                    boolean canChat = false;
                    String chkSql =
                        "SELECT 1 " +
                        "FROM followings " +
                        "WHERE user_id = ? AND follower_id = ?";
                    try (PreparedStatement ps = con.prepareStatement(chkSql)) {
                        ps.setString(1, currentUser);
                        ps.setString(2, peer);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) canChat = true;
                        }
                    }

                    if (!canChat) {
                        infoMsg = "메시지는 내가 팔로우한 사용자에게만 보낼 수 있습니다";
                    } else {
                        String mid = "m" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                        String insSql =
                            "INSERT INTO message (m_id, sender, receiver, content) " +
                            "VALUES (?, ?, ?, ?)";
                        try (PreparedStatement ps = con.prepareStatement(insSql)) {
                            ps.setString(1, mid);
                            ps.setString(2, currentUser);
                            ps.setString(3, peer);
                            ps.setString(4, content);
                            ps.executeUpdate();
                        }

                        if (con != null) {
                            try { con.close(); } catch (Exception ignore) {}
                        }
                        response.sendRedirect("messages.jsp?peer=" + java.net.URLEncoder.encode(peer, "UTF-8"));
                        return;
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    errorMsg = "메시지를 보내는 중 오류가 발생했어요";
                }
            }
        }
    }

    // 왼쪽 목록  1  내가 팔로우한 사람들
    List<Map<String,String>> userList = new ArrayList<Map<String,String>>();
    Set<String> addedIds = new HashSet<String>();

    try {
        String uSql =
            "SELECT u.user_id, u.status_message, u.paid " +
            "FROM users u " +
            "JOIN followings f ON f.follower_id = u.user_id " +
            "WHERE f.user_id = ? " +
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
                    row.put("rel", "follow");
                    userList.add(row);
                    if (uid != null) addedIds.add(uid);
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
        if (errorMsg == null) errorMsg = "대화 가능한 사용자 목록을 불러오는 중 오류가 발생했어요";
    }

    // 왼쪽 목록  2  나와 메시지를 주고받은 사람들  내가 팔로우 안 해도 포함
    try {
        String convSql =
            "SELECT DISTINCT " +
            "  CASE WHEN sender = ? THEN receiver ELSE sender END AS peer_id " +
            "FROM message " +
            "WHERE sender = ? OR receiver = ?";
        try (PreparedStatement ps = con.prepareStatement(convSql)) {
            ps.setString(1, currentUser);
            ps.setString(2, currentUser);
            ps.setString(3, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String peerId = rs.getString("peer_id");
                    if (peerId == null || peerId.equals(currentUser)) continue;
                    if (addedIds.contains(peerId)) continue;

                    String infoSql =
                        "SELECT user_id, status_message, paid " +
                        "FROM users WHERE user_id = ?";
                    try (PreparedStatement ps2 = con.prepareStatement(infoSql)) {
                        ps2.setString(1, peerId);
                        try (ResultSet rs2 = ps2.executeQuery()) {
                            if (rs2.next()) {
                                Map<String,String> row = new HashMap<String,String>();
                                row.put("user_id", rs2.getString("user_id"));
                                row.put("status_message", rs2.getString("status_message"));
                                row.put("paid", rs2.getString("paid"));
                                row.put("rel", "msg");
                                userList.add(row);
                                addedIds.add(peerId);
                            }
                        }
                    }
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
        if (errorMsg == null) errorMsg = "대화 가능한 사용자 목록을 불러오는 중 오류가 발생했어요";
    }

    // 선택된 상대 정보
    String peerStatus = null;
    String peerPaid = null;
    boolean peerExists = false;

    if (selectedPeer != null && !selectedPeer.isEmpty()) {
        try {
            boolean userExists = false;
            String pSql =
                "SELECT status_message, paid " +
                "FROM users WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(pSql)) {
                ps.setString(1, selectedPeer);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        userExists = true;
                        peerStatus = rs.getString("status_message");
                        peerPaid = rs.getString("paid");
                    }
                }
            }

            boolean peerInFollowings = false;
            String fSql =
                "SELECT 1 FROM followings " +
                "WHERE user_id = ? AND follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(fSql)) {
                ps.setString(1, currentUser);
                ps.setString(2, selectedPeer);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) peerInFollowings = true;
                }
            }

            boolean peerInMessages = false;
            String mCheckSql =
                "SELECT 1 FROM message " +
                "WHERE (sender = ? AND receiver = ?) " +
                "   OR (sender = ? AND receiver = ?) " +
                "LIMIT 1";
            try (PreparedStatement ps = con.prepareStatement(mCheckSql)) {
                ps.setString(1, currentUser);
                ps.setString(2, selectedPeer);
                ps.setString(3, selectedPeer);
                ps.setString(4, currentUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) peerInMessages = true;
                }
            }

            peerExists = userExists && (peerInFollowings || peerInMessages);
        } catch (Exception e) {
            e.printStackTrace();
            if (errorMsg == null) errorMsg = "대화 상대 정보를 불러오는 중 오류가 발생했어요";
        }
    }

    // 대화 내용  created_at 기준으로 오래된 → 새로운 순서 정렬
    List<Map<String,Object>> chatList = new ArrayList<Map<String,Object>>();
    if (peerExists) {
        try {
            String mSql =
                "SELECT m_id, sender, receiver, content, created_at " +
                "FROM message " +
                "WHERE (sender = ? AND receiver = ?) " +
                "   OR (sender = ? AND receiver = ?) " +
                "ORDER BY created_at ASC";
            try (PreparedStatement ps = con.prepareStatement(mSql)) {
                ps.setString(1, currentUser);
                ps.setString(2, selectedPeer);
                ps.setString(3, selectedPeer);
                ps.setString(4, currentUser);
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
        } catch (Exception e) {
            e.printStackTrace();
            if (errorMsg == null) errorMsg = "대화 내용을 불러오는 중 오류가 발생했어요";
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>메시지  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">메시지</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn" title="설정은 로그인 후 이용 가능">⚙</a>
                <a href="login.jsp" class="icon-btn" title="메시지는 로그인 후 이용 가능">💬</a>
            <%
                } else {
            %>
                <!-- 왼쪽부터: 검색 / 프로필 / 설정 / DM -->
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= currentInitial %></a>
                <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
                <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
            <%
                }
            %>
        </div>
    </header>


    <div class="messages-layout">

        <!-- 왼쪽  사용자 목록 -->
        <div class="messages-left">
            <div class="list-header">
                대화 상대 선택
            </div>
            <div class="user-list">
                <%
                    if (userList.isEmpty()) {
                %>
                    <div style="padding:10px;" class="helper-text">
                        아직 팔로우하거나 메시지를 주고받은 사용자가 없습니다  
                        메시지를 보내기 위해 사용자를 팔로우하세요
                    </div>
                <%
                    } else {
                        for (Map<String,String> u : userList) {
                            String uid = u.get("user_id");
                            String ust = u.get("status_message");
                            String upaid = u.get("paid");
                            String rel = u.get("rel");
                            boolean active = (selectedPeer != null && selectedPeer.equals(uid));
                %>
                    <div class="user-item <%= active ? "active" : "" %>">
                        <a href="profile.jsp?user=<%= uid %>" class="avatar-sm-link">
                            <div class="avatar-sm">
                                <%= (uid != null && uid.length() > 0) ? uid.substring(0,1).toUpperCase() : "U" %>
                            </div>
                        </a>
                        <div style="flex:1; min-width:0;">
                            <div class="user-name-row">
                                <a href="profile.jsp?user=<%= uid %>" class="username-link">
                                    <%= uid %>
                                </a>
                                <%
                                    if ("T".equals(upaid)) {
                                %>
                                <span class="badge-check">✓</span>
                                <%
                                    }
                                %>
                            </div>
                            <div class="user-status">
                                <%= (ust == null || ust.trim().isEmpty())
                                        ? ("follow".equals(rel) ? "상태메시지 없음" : "메시지 수신 기록 있음")
                                        : ust %>
                            </div>
                        </div>
                        <a href="messages.jsp?peer=<%= uid %>" class="btn-secondary btn-sm">
                            채팅
                        </a>
                    </div>
                <%
                        }
                    }
                %>
            </div>
        </div>

        <!-- 오른쪽  채팅 영역 -->
        <div class="messages-right">
            <%
                if (selectedPeer == null || selectedPeer.isEmpty()) {
            %>
                <div class="chat-header">
                    <div class="chat-title">대화 상대를 선택해 주세요</div>
                    <div class="chat-subtitle">
                        왼쪽 목록에서 메시지를 주고받을 사용자를 클릭하면  
                        이곳에 대화 내용이 표시됩니다
                    </div>
                </div>
                <div class="chat-body" style="justify-content:center; align-items:center;">
                    <div class="helper-text">
                        왼쪽에서 대화할 사용자를 선택하면  
                        이 영역에서 메시지를 주고받을 수 있습니다
                    </div>
                </div>
            <%
                } else if (!peerExists) {
            %>
                <div class="chat-header">
                    <div class="chat-title">대화 상대를 찾을 수 없습니다</div>
                    <div class="chat-subtitle">
                        이 사용자는 존재하지 않거나  
                        나와 팔로우 또는 메시지 기록이 없습니다
                    </div>
                </div>
                <div class="chat-body" style="justify-content:center; align-items:center;">
                    <div class="helper-text">
                        다른 사용자를 선택하거나, 먼저 팔로우나 메시지를 주고받은 후 다시 시도해 주세요
                    </div>
                </div>
            <%
                } else {
                    boolean peerIsPaid = "T".equals(peerPaid);
                    String peerInitial = selectedPeer.substring(0, 1).toUpperCase();
            %>
                <!-- 채팅 헤더 -->
                <div class="chat-header">
                    <div style="display:flex; align-items:center; gap:8px;">
                        <a href="profile.jsp?user=<%= selectedPeer %>" class="avatar-sm-link">
                            <div class="avatar-sm"><%= peerInitial %></div>
                        </a>
                        <div>
                            <div class="chat-title">
                                <a href="profile.jsp?user=<%= selectedPeer %>" class="username-link">
                                    <%= selectedPeer %>
                                </a>
                                <%
                                    if (peerIsPaid) {
                                %>
                                <span class="badge-check" style="margin-left:4px;">✓</span>
                                <%
                                    }
                                %>
                            </div>
                            <div class="chat-subtitle">
                                <%= (peerStatus == null || peerStatus.trim().isEmpty())
                                        ? "상태메시지 없음"
                                        : peerStatus %>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- 채팅 본문  created_at ASC 순서 그대로 출력  오래된 위 새 메시지 아래 -->
                <div class="chat-body">
                    <%
                        if (chatList.isEmpty()) {
                    %>
                        <div class="helper-text">
                            아직 주고받은 메시지가 없습니다  
                            내가 팔로우한 사용자라면 아래 입력창에서 첫 메시지를 보내 보세요
                        </div>
                    <%
                        } else {
                            for (Map<String,Object> m : chatList) {
                                boolean isMe = (Boolean) m.get("isMe");
                                String sender = (String) m.get("sender");
                                String content = (String) m.get("content");
                                boolean senderIsMe = currentUser.equals(sender);
                    %>
                        <div class="chat-row <%= isMe ? "me" : "other" %>">
                            <div class="chat-bubble <%= isMe ? "me" : "other" %>">
                                <%= (content == null ? "" : content) %>
                            </div>
                        </div>
                        <div class="chat-meta <%= isMe ? "me" : "other" %>">
                            <%
                                if (senderIsMe) {
                            %>
                                나
                            <%
                                } else {
                            %>
                                <a href="profile.jsp?user=<%= sender %>" class="username-link">
                                    <%= sender %>
                                </a>
                            <%
                                }
                            %>
                        </div>
                    <%
                            }
                        }
                    %>
                </div>

                <!-- 입력 바 -->
                <div class="chat-input-bar">
                    <form method="post" action="messages.jsp" class="chat-input-form">
                        <input type="hidden" name="mode" value="send">
                        <input type="hidden" name="peer" value="<%= selectedPeer %>">
                        <input type="text" name="content" class="chat-input"
                               placeholder="<%= selectedPeer %>에게 메시지 보내기  (내가 팔로우한 사용자만 전송 가능)">
                        <button type="submit" class="chat-send-btn">보내기</button>
                    </form>
                    <%
                        if (infoMsg != null) {
                    %>
                        <div class="msg msg-err" style="margin-top:4px;"><%= infoMsg %></div>
                    <%
                        }
                    %>
                </div>
            <%
                }
            %>
        </div>

    </div>

    <%
        if (errorMsg != null) {
    %>
        <div class="msg msg-err" style="position:fixed; bottom:8px; left:50%; transform:translateX(-50%); max-width:480px;">
            <%= errorMsg %>
        </div>
    <%
        }
    %>

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
