<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    // 볼 프로필 대상
    String profileUser = request.getParameter("user");
    if (profileUser != null) profileUser = profileUser.trim();
    if ((profileUser == null || profileUser.isEmpty()) && currentUser != null) {
        profileUser = currentUser;
    }

    String errorMsg = null;
    if (profileUser == null || profileUser.isEmpty()) {
        errorMsg = "어떤 사용자의 프로필을 보여줄지 알 수 없습니다";
    }

    String initials = "U";
    if (profileUser != null && profileUser.length() > 0) {
        initials = profileUser.substring(0,1).toUpperCase();
    }

    boolean isOwner = (currentUser != null && profileUser != null && currentUser.equals(profileUser));

    // 대상 유저 정보
    String statusMsg = null;
    String paidStr   = null;
    String isPrivate = "F";
    boolean userExists = false;

    int followerCount  = 0;
    int followingCount = 0;

    boolean alreadyFollowing = false;
    boolean alreadyRequested = false;
    boolean profilePaid    = false;
    boolean profilePrivate = false;
    boolean canViewPosts   = true;   // 비밀계정 게시글 보기 권한

    List<Map<String,Object>> posts = new ArrayList<Map<String,Object>>();
    List<Map<String,Object>> followRequests = new ArrayList<Map<String,Object>>();

    try {
        if (errorMsg == null) {
            // 기본 정보
            String uq =
                "SELECT user_id, status_message, paid, is_private " +
                "FROM users WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(uq)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        userExists   = true;
                        statusMsg    = rs.getString("status_message");
                        paidStr      = rs.getString("paid");
                        isPrivate    = rs.getString("is_private");
                        if (isPrivate == null) isPrivate = "F";

                        profilePaid    = "T".equals(paidStr);
                        profilePrivate = "T".equals(isPrivate);
                    }
                }
            }
            if (!userExists) errorMsg = "해당 사용자를 찾을 수 없습니다";
        }

        if (errorMsg == null) {
            // 팔로워/팔로잉 수 (followings 사용)
            String fq1 = "SELECT COUNT(*) FROM followings WHERE follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(fq1)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) followerCount = rs.getInt(1);
                }
            }
            String fq2 = "SELECT COUNT(*) FROM followings WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(fq2)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) followingCount = rs.getInt(1);
                }
            }

            // 내가 이 사람을 팔로우 중인지 / 요청 보냈는지
            if (currentUser != null && !isOwner) {
                // followings(user_id, follower_id) : user_id 가 follower_id 를 팔로우
                String chkFollow =
                    "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chkFollow)) {
                    ps.setString(1, currentUser);   // 나
                    ps.setString(2, profileUser);   // 이 프로필
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) alreadyFollowing = true;
                    }
                }
                String chkReq =
                    "SELECT 1 FROM follow_requests WHERE requester_id = ? AND target_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chkReq)) {
                    ps.setString(1, currentUser);
                    ps.setString(2, profileUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) alreadyRequested = true;
                    }
                }
            }

            // 비밀계정 게시글 열람 권한
            canViewPosts = true;
            if (profilePrivate && !isOwner) {
                if (currentUser == null) {
                    canViewPosts = false;
                } else if (!alreadyFollowing) {
                    canViewPosts = false;
                }
            }

            // 이 유저의 게시글 (볼 권한 있을 때만 조회)
            if (canViewPosts) {
                String psql =
                    "SELECT p.post_id, p.content, p.num_of_likes, " +
                    "       u.user_id AS writer_id, u.status_message, u.paid, " +
                    "       (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comment_count " +
                    "FROM posts p " +
                    "JOIN users u ON u.user_id = p.writer_id " +
                    "WHERE p.writer_id = ? " +
                    "ORDER BY p.post_id DESC";
                try (PreparedStatement ps = con.prepareStatement(psql)) {
                    ps.setString(1, profileUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            Map<String,Object> row = new HashMap<String,Object>();
                            row.put("post_id", rs.getString("post_id"));
                            row.put("content", rs.getString("content"));
                            row.put("likes", rs.getInt("num_of_likes"));
                            row.put("writer_status", rs.getString("status_message"));
                            row.put("writer_paid", rs.getString("paid"));
                            row.put("comment_count", rs.getInt("comment_count"));
                            posts.add(row);
                        }
                    }
                }
            }

            // 받은 팔로우 요청 목록 (내 프로필일 때만)
            if (isOwner) {
                String rsql =
                    "SELECT fr.req_id, fr.requester_id, u.status_message, u.paid " +
                    "FROM follow_requests fr " +
                    "JOIN users u ON u.user_id = fr.requester_id " +
                    "WHERE fr.target_id = ? " +
                    "ORDER BY fr.created_at ASC";
                try (PreparedStatement ps = con.prepareStatement(rsql)) {
                    ps.setString(1, currentUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            Map<String,Object> row = new HashMap<String,Object>();
                            row.put("req_id", rs.getString("req_id"));
                            row.put("requester_id", rs.getString("requester_id"));
                            row.put("status_message", rs.getString("status_message"));
                            row.put("paid", rs.getString("paid"));
                            followRequests.add(row);
                        }
                    }
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
        if (errorMsg == null) errorMsg = "프로필 정보를 불러오는 중 오류가 발생했습니다";
    }

    int postCount = posts.size();

    String currentInitial = "G";
    if (currentUser != null && currentUser.length() > 0) {
        currentInitial = currentUser.substring(0,1).toUpperCase();
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title><%= profileUser %> 프로필  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">

    <!-- 메인 타임라인과 같은 레이아웃 사용 -->
    <style>
        .home-layout {
            display: flex;
            justify-content: center;
            gap: 16px;
            margin-top: 16px;
        }
        .home-main {
            flex: 0 0 680px;
            max-width: 680px;
        }
        .home-side {
            flex: 0 0 320px;
            max-width: 320px;
        }
        @media (max-width: 960px) {
            .home-layout {
                flex-direction: column;
            }
            .home-main,
            .home-side {
                flex: 1 1 auto;
                max-width: 100%;
                margin: 0 8px;
            }
        }
    </style>
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">프로필</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <!-- 사용자 검색 (비로그인도 프로필 보는 건 가능하게) -->
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn">⚙</a>
                <a href="login.jsp" class="icon-btn">💬</a>
            <%
                } else {
            %>
                <!-- 여기! 프로필 아이콘 왼쪽에 검색 -->
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= currentInitial %></a>
                <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
                <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <!-- 가운데: 프로필 + 게시글 / 오른쪽: 팔로우 요청 -->
    <div class="home-layout">

        <!-- 프로필 + 게시글 -->
        <div class="home-main">
            <div class="card">
                <%
                    if (errorMsg != null) {
                %>
                    <div class="msg msg-err"><%= errorMsg %></div>
                <%
                    } else {
                %>
                <div style="display:flex; gap:16px; align-items:center;">
                    <div class="avatar-lg"><%= initials %></div>
                    <div style="flex:1;">
                        <div class="post-username-row">
                            <span class="username-link"><%= profileUser %></span>
                            <%
                                if (profilePaid) {
                            %>
                            <span class="badge-check">✓</span>
                            <%
                                }
                                if (profilePrivate) {
                            %>
                            <span class="badge-pill">🔒</span>
                            <%
                                } else {
                            %>
                            <span class="badge-pill badge-light"></span>
                            <%
                                }
                            %>
                        </div>
                        <div class="post-meta">
                            <%= (statusMsg == null || statusMsg.trim().isEmpty())
                                    ? "상태메시지 없음"
                                    : statusMsg %>
                        </div>
                        <div class="post-meta" style="margin-top:4px;">
                            팔로워
                            <a href="followerList.jsp?user=<%= profileUser %>" class="post-meta-link">
                                <strong><%= followerCount %></strong>명
                            </a>
                            &nbsp;&nbsp;
                            팔로잉
                            <a href="followingList.jsp?user=<%= profileUser %>" class="post-meta-link">
                                <strong><%= followingCount %></strong>명
                            </a>
                        </div>
                    </div>

                    <div>
                        <%
                            if (!isOwner) {
                                if (currentUser == null) {
                        %>
                            <a href="login.jsp" class="btn-primary btn-sm">로그인 후 팔로우</a>
                        <%
                                } else if (alreadyFollowing) {
                        %>
                            <form method="post" action="followUser.jsp">
                                <input type="hidden" name="target_id" value="<%= profileUser %>">
                                <button type="submit" class="btn-secondary btn-sm">언팔로우</button>
                            </form>
                        <%
                                } else if (profilePrivate && alreadyRequested) {
                        %>
                            <button type="button" class="btn-secondary btn-sm" disabled>
                                팔로우 요청 보냄
                            </button>
                        <%
                                } else {
                        %>
                            <form method="post" action="followUser.jsp">
                                <input type="hidden" name="target_id" value="<%= profileUser %>">
                                <button type="submit" class="btn-primary btn-sm">팔로우</button>
                            </form>
                        <%
                                }
                            } else {
                        %>
                            <span class="helper-text">내 계정입니다</span>
                        <%
                            }
                        %>
                    </div>
                </div>
                <%
                    }
                %>
            </div>

            <!-- 게시글 카드 -->
            <div class="card">
                <div class="section-title">
                    <%= profileUser %> 님의 게시글 <%= postCount %>개
                </div>
                <%
                    if (errorMsg != null) {
                        // 위에서 이미 표시
                    } else if (!canViewPosts) {
                %>
                    <div class="helper-text">
                        비밀계정이에요 팔로우한 사람만 게시글을 볼 수 있습니다
                    </div>
                <%
                    } else if (posts.isEmpty()) {
                %>
                    <div class="helper-text">아직 작성된 게시글이 없습니다</div>
                <%
                    } else {
                        for (Map<String,Object> row : posts) {
                            String pid    = (String) row.get("post_id");
                            String pcont  = (String) row.get("content");
                            int    likes  = (Integer) row.get("likes");
                            int    ccount = (Integer) row.get("comment_count");
                %>
                <article class="post-card">
                    <div class="post-header">
                        <div class="post-user">
                            <a href="profile.jsp?user=<%= profileUser %>" class="avatar-sm-link">
                                <div class="avatar-sm"><%= initials %></div>
                            </a>
                            <div>
                                <div class="post-username-row">
                                    <span class="username-link"><%= profileUser %></span>
                                    <%
                                        if (profilePaid) {
                                    %>
                                    <span class="badge-check">✓</span>
                                    <%
                                        }
                                    %>
                                </div>
                                <div class="post-meta">
                                    <%= (statusMsg == null || statusMsg.trim().isEmpty())
                                            ? "상태메시지 없음"
                                            : statusMsg %>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="post-content">
                        <a href="postDetail.jsp?post_id=<%= pid %>"
                           style="color:#050505; text-decoration:none;">
                            <%= (pcont == null ? "" : pcont) %>
                        </a>
                    </div>

                    <div class="post-footer-row">
                        <span class="post-meta-item">post_id <strong><%= pid %></strong></span>
                        <span class="post-meta-item">좋아요 <strong><%= likes %></strong>개</span>
                        <span class="post-meta-item">댓글 <strong><%= ccount %></strong>개</span>
                        <a href="postDetail.jsp?post_id=<%= pid %>" class="post-meta-link">
                            댓글 포함 자세히 보기
                        </a>
                    </div>
                </article>
                <%
                        }
                    }
                %>
            </div>
        </div>

        <!-- 오른쪽: 받은 팔로우 요청 -->
        <div class="home-side">
            <%
                if (isOwner) {
            %>
            <div class="card">
                <div class="section-title">받은 팔로우 요청</div>
                <%
                    if (followRequests.isEmpty()) {
                %>
                    <div class="helper-text">받은 팔로우 요청이 없습니다</div>
                <%
                    } else {
                        for (Map<String,Object> row : followRequests) {
                            String reqId   = (String) row.get("req_id");
                            String rid     = (String) row.get("requester_id");
                            String rstatus = (String) row.get("status_message");
                            String rpaid   = (String) row.get("paid");
                            boolean rp     = "T".equals(rpaid);
                %>
                    <div class="user-item">
                        <a href="profile.jsp?user=<%= rid %>" class="avatar-sm-link">
                            <div class="avatar-sm"><%= rid.substring(0,1).toUpperCase() %></div>
                        </a>
                        <div class="user-suggest-main">
                            <div class="user-name-row">
                                <a href="profile.jsp?user=<%= rid %>" class="username-link"><%= rid %></a>
                                <%
                                    if (rp) {
                                %>
                                <span class="badge-check">✓</span>
                                <%
                                    }
                                %>
                            </div>
                            <div class="user-status">
                                <%= (rstatus == null || rstatus.trim().isEmpty())
                                        ? "상태메시지 없음"
                                        : rstatus %>
                            </div>
                        </div>
                        <div style="display:flex; gap:4px;">
                            <form method="post" action="handleFollowRequest.jsp" style="margin:0;">
                                <input type="hidden" name="req_id" value="<%= reqId %>">
                                <input type="hidden" name="action" value="approve">
                                <button type="submit" class="btn-primary btn-xs">승인</button>
                            </form>
                            <form method="post" action="handleFollowRequest.jsp" style="margin:0;">
                                <input type="hidden" name="req_id" value="<%= reqId %>">
                                <input type="hidden" name="action" value="reject">
                                <button type="submit" class="btn-secondary btn-xs">거절</button>
                            </form>
                        </div>
                    </div>
                <%
                        }
                    }
                %>
            </div>
            <%
                }
            %>
        </div>

    </div><!-- /.home-layout -->

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
