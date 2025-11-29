<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*, java.text.SimpleDateFormat" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    // 프로필 대상 설정
    String profileUser = request.getParameter("user");
    if (profileUser != null) profileUser = profileUser.trim();
    if ((profileUser == null || profileUser.isEmpty()) && currentUser != null) {
        profileUser = currentUser;
    }

    String errorMsg = null;
    if (profileUser == null || profileUser.isEmpty()) {
        errorMsg = "사용자를 찾을 수 없습니다";
    }

    String initials = "U";
    if (profileUser != null && profileUser.length() > 0) {
        initials = profileUser.substring(0,1).toUpperCase();
    }

    boolean isOwner = (currentUser != null && profileUser != null && currentUser.equals(profileUser));

    // 변수 초기화
    String statusMsg = null;
    String paidStr   = null;
    String isPrivate = "F";
    String profileImg = null;
    boolean userExists = false;
    
    int followerCount  = 0;
    int followingCount = 0;
    
    boolean alreadyFollowing = false;
    boolean alreadyRequested = false;
    
    boolean profilePaid    = false;
    boolean profilePrivate = false;
    boolean canViewPosts   = true;

    List<Map<String,Object>> posts = new ArrayList<>();
    List<Map<String,Object>> followRequests = new ArrayList<>();

    try {
        if (errorMsg == null) {
            // 1. 유저 정보 조회
            String uq = "SELECT user_id, status_message, paid, is_private, profile_img FROM users WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(uq)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        userExists = true;
                        statusMsg  = rs.getString("status_message");
                        paidStr    = rs.getString("paid");
                        isPrivate  = rs.getString("is_private");
                        profileImg = rs.getString("profile_img");
                        
                        if (isPrivate == null) isPrivate = "F";
                        profilePaid = "T".equals(paidStr);
                        profilePrivate = "T".equals(isPrivate);
                    }
                }
            }
            if (!userExists) errorMsg = "해당 사용자를 찾을 수 없습니다";
        }

        if (errorMsg == null) {
            // 2. [수정됨] 팔로워/팔로잉 수 카운트 (반대로 되어있던 것 수정)
            
            // 팔로워 수 (나를 팔로우하는 사람 = followings 테이블의 user_id가 나인 경우)
            String fq1 = "SELECT COUNT(*) FROM followings WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(fq1)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) { if (rs.next()) followerCount = rs.getInt(1); }
            }
            
            // 팔로잉 수 (내가 팔로우하는 사람 = followings 테이블의 follower_id가 나인 경우)
            String fq2 = "SELECT COUNT(*) FROM followings WHERE follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(fq2)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) { if (rs.next()) followingCount = rs.getInt(1); }
            }

            // 3. 나와의 관계 확인 (버튼 상태)
            if (currentUser != null && !isOwner) {
                // 이미 팔로우 중인지
                String chkFollow = "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chkFollow)) {
                    ps.setString(1, profileUser); // 타겟
                    ps.setString(2, currentUser); // 나
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) alreadyFollowing = true; }
                }
                
                // 이미 요청 중인지 (비공개일 때)
                String chkReq = "SELECT 1 FROM follow_requests WHERE target_id = ? AND requester_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chkReq)) {
                    ps.setString(1, profileUser);
                    ps.setString(2, currentUser);
                    try (ResultSet rs = ps.executeQuery()) { if (rs.next()) alreadyRequested = true; }
                }
            }

            // 4. 게시글 열람 권한
            canViewPosts = true;
            if (profilePrivate && !isOwner) {
                if (currentUser == null) { canViewPosts = false; }
                else if (!alreadyFollowing) { canViewPosts = false; }
            }

            // 5. 게시글 목록 조회
            if (canViewPosts) {
                String psql = "SELECT p.post_id, p.content, p.num_of_likes, p.created_at, p.img_file, u.user_id, u.profile_img, " +
                              "(SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id) AS comment_count " +
                              "FROM posts p JOIN users u ON u.user_id = p.writer_id " +
                              "WHERE p.writer_id = ? ORDER BY p.created_at DESC";
                try (PreparedStatement ps = con.prepareStatement(psql)) {
                    ps.setString(1, profileUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            Map<String,Object> row = new HashMap<>();
                            row.put("post_id", rs.getString("post_id"));
                            row.put("content", rs.getString("content"));
                            row.put("likes", rs.getInt("num_of_likes"));
                            row.put("comment_count", rs.getInt("comment_count"));
                            row.put("img_file", rs.getString("img_file"));
                            row.put("writer_img", rs.getString("profile_img"));
                            
                            Timestamp ts = rs.getTimestamp("created_at");
                            row.put("created_at", (ts!=null) ? new SimpleDateFormat("yyyy-MM-dd HH:mm").format(ts) : "");

                            boolean isLiked = false;
                            if (currentUser != null) {
                                String likeChk = "SELECT 1 FROM post_likes WHERE post_id=? AND liker_id=?";
                                try (PreparedStatement psLike = con.prepareStatement(likeChk)) {
                                    psLike.setString(1, rs.getString("post_id"));
                                    psLike.setString(2, currentUser);
                                    try (ResultSet rsLike = psLike.executeQuery()) { if (rsLike.next()) isLiked = true; }
                                }
                            }
                            row.put("isLiked", isLiked);
                            posts.add(row);
                        }
                    }
                }
            }
            
            // 6. 팔로우 요청 목록 (주인만)
            if (isOwner) {
                String rsql = "SELECT fr.req_id, fr.requester_id, u.status_message, u.profile_img FROM follow_requests fr JOIN users u ON u.user_id = fr.requester_id WHERE fr.target_id = ? ORDER BY fr.created_at ASC";
                try (PreparedStatement ps = con.prepareStatement(rsql)) {
                    ps.setString(1, currentUser);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            Map<String,Object> row = new HashMap<>();
                            row.put("req_id", rs.getString("req_id"));
                            row.put("requester_id", rs.getString("requester_id"));
                            row.put("status_message", rs.getString("status_message"));
                            row.put("requester_img", rs.getString("profile_img"));
                            followRequests.add(row);
                        }
                    }
                }
            }
        }
    } catch (Exception e) { e.printStackTrace(); }

    int postCount = posts.size();
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title><%= profileUser %> 프로필 / Twitter</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">   
    <style>
        .home-layout { display: flex; justify-content: center; gap: 16px; margin-top: 16px; }
        .home-main { flex: 0 0 680px; max-width: 680px; }
        .home-side { flex: 0 0 320px; max-width: 320px; }
        @media (max-width: 960px) {
            .home-layout { flex-direction: column; }
            .home-main, .home-side { flex: 1 1 auto; max-width: 100%; margin: 0 8px; }
        }
        .fa-solid.fa-heart { color: #f91880; }
        .post-header-top-right { position: absolute; top: 10px; right: 10px; }
        .post-actions-row { display: flex; justify-content: flex-start; align-items: center; width: 100%; }
        .post-action-btn-group { display: flex; align-items: center; gap: 20px; }
        .post-action-btn-group .post-like-btn-inline { margin-left: 0 !important; }
        .avatar-lg-img { width: 134px; height: 134px; border-radius: 50%; object-fit: cover; border: 4px solid #fff; background-color: #fff; }
        .avatar-sm-img { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; border: 1px solid #cfd9de; }
        .btn-requested { background-color: #fff !important; border: 1px solid #cfd9de !important; color: #0f1419 !important; }
    </style>
</head>
<body>
<div class="app-shell">

    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">프로필</div>
        </div>
        <div class="app-header-right">
            <% if (currentUser == null) { %>
                <a href="login.jsp" class="icon-btn"><i class="fa-solid fa-user"></i></a>
            <% } else { %>
                <a href="followList.jsp" class="icon-btn"><i class="fa-solid fa-magnifying-glass"></i></a>
                <a href="profile.jsp" class="icon-btn"><%= initials %></a>
                <a href="settings.jsp" class="icon-btn"><i class="fa-solid fa-gear"></i></a>
                <a href="messages.jsp" class="icon-btn"><i class="fa-regular fa-comments"></i></a>
            <% } %>
        </div>
    </header>

    <div class="home-layout">
        <div class="home-main">
            <div class="card">
                <% if (errorMsg != null) { %>
                    <div class="msg msg-err"><%= errorMsg %></div>
                <% } else { %>
                <div style="display:flex; gap:16px; align-items:center;">
                    
                    <% if(profileImg != null && !profileImg.isEmpty()) { %>
                        <img src="uploads/<%= profileImg %>" class="avatar-lg-img">
                    <% } else { %>
                        <div class="avatar-lg"><%= initials %></div>
                    <% } %>

                    <div style="flex:1;">
                        <div class="post-username-row">
                            <span class="username-link" style="font-size: 20px;"><%= profileUser %></span>
                            <% if (profilePaid) { %><span class="badge-check">✓</span><% } %>
                            <% if (profilePrivate) { %><span class="badge-pill">🔒</span><% } %>
                        </div>
                        <div class="post-meta">
                            <%= (statusMsg == null || statusMsg.trim().isEmpty()) ? "상태메시지 없음" : statusMsg %>
                        </div>
                        <div class="post-meta" style="margin-top:8px;">
                            <a href="followerList.jsp?user=<%= profileUser %>" class="post-meta-link">
                                <strong><%= followerCount %></strong> 팔로워
                            </a>
                            &nbsp;&nbsp;
                            <a href="followingList.jsp?user=<%= profileUser %>" class="post-meta-link">
                                <strong><%= followingCount %></strong> 팔로잉
                            </a>
                        </div>
                    </div>

                    <div>
                        <% if (!isOwner) { 
                                if (currentUser == null) { %>
                            <a href="login.jsp" class="btn-primary btn-sm">로그인</a>
                        <% } else if (alreadyFollowing) { %>
                            <form method="post" action="followUser.jsp">
                                <input type="hidden" name="target_id" value="<%= profileUser %>">
                                <button type="submit" class="btn-secondary btn-sm">언팔로우</button>
                            </form>
                        <% } else if (alreadyRequested) { %>
                            <form method="post" action="followUser.jsp" style="margin:0;">
                                <input type="hidden" name="target_id" value="<%= profileUser %>">
                                <button type="submit" class="btn-secondary btn-sm btn-requested">요청됨</button>
                            </form>
                        <% } else { %>
                            <form method="post" action="followUser.jsp">
                                <input type="hidden" name="target_id" value="<%= profileUser %>">
                                <button type="submit" class="btn-primary btn-sm">팔로우</button>
                            </form>
                        <% } 
                           } else { %>
                            <a href="settings.jsp" class="btn-ghost btn-sm">프로필 수정</a>
                        <% } %>
                    </div>
                </div>
                <% } %>
            </div>

            <div class="card">
                <div class="section-title">게시글 (<%= postCount %>)</div>
                <% if (!canViewPosts) { %>
                    <div class="helper-text" style="padding:20px; text-align:center;">
                        <i class="fa-solid fa-lock" style="font-size:24px; margin-bottom:10px;"></i><br>
                        비밀 계정입니다.<br>팔로우 승인된 사용자만 볼 수 있습니다.
                    </div>
                <% } else if (posts.isEmpty()) { %>
                    <div class="helper-text" style="padding:20px; text-align:center;">게시글이 없습니다</div>
                <% } else {
                    for (Map<String,Object> row : posts) {
                        String pid = (String) row.get("post_id");
                        String pcont = (String) row.get("content");
                        int likes = (Integer) row.get("likes");
                        int ccount = (Integer) row.get("comment_count");
                        String imgFile = (String) row.get("img_file");
                        boolean isLiked = (Boolean) row.get("isLiked");
                        String wImg = (String) row.get("writer_img");
                %>
                <article class="post-card" style="position:relative;" id="post-<%= pid %>">
                    <div class="post-header">
                        <div class="post-user">
                            <a href="profile.jsp?user=<%= profileUser %>" class="avatar-sm-link">
                                <% if(wImg != null && !wImg.isEmpty()) { %>
                                    <img src="uploads/<%= wImg %>" class="avatar-sm-img">
                                <% } else { %>
                                    <div class="avatar-sm"><%= initials %></div>
                                <% } %>
                            </a>
                            <div>
                                <div class="post-username-row">
                                    <span class="username-link"><%= profileUser %></span>
                                    <% if (profilePaid) { %><span class="badge-check">✓</span><% } %>
                                    <span style="font-weight:400; color:#536471; font-size:13px; margin-left:6px;">· <%= row.get("created_at") %></span>
                                </div>
                            </div>
                        </div>
                        <% if (isOwner) { %>
                        <div class="post-header-top-right">
                            <form method="post" action="deletePost.jsp" style="margin:0;">
                                <input type="hidden" name="post_id" value="<%= pid %>">
                                <button type="submit" class="icon-btn" title="삭제"><i class="fa-solid fa-trash-can"></i></button>
                            </form>
                        </div>
                        <% } %>
                    </div>

                    <div class="post-content">
                        <a href="postDetail.jsp?post_id=<%= pid %>" style="color:#0f1419; text-decoration:none;">
                            <%= pcont %>
                        </a>
                        <% if(imgFile != null && !imgFile.isEmpty()) { %>
                            <img src="uploads/<%= imgFile %>" class="post-image" alt="이미지">
                        <% } %>
                    </div>

                    <div class="post-actions-bar" style="border:none; padding-top:0;">
                        <div class="post-actions-row">
                            <div class="post-action-btn-group">
                                <form method="post" action="likePost.jsp" style="margin:0; display:inline-flex;">
                                    <input type="hidden" name="post_id" value="<%= pid %>">
                                    <button type="submit" class="post-like-btn-inline">
                                        <i class="<%= isLiked ? "fa-solid fa-heart" : "fa-regular fa-heart" %>" style="<%= isLiked ? "color:#f91880;" : "" %>"></i>
                                    </button>
                                    <span style="font-size:13px; color:#536471; margin-left:4px;"><%= likes %></span>
                                </form>
                                <a href="postDetail.jsp?post_id=<%= pid %>" class="post-like-btn-inline" style="text-decoration:none;">
                                    <i class="fa-regular fa-comment"></i>
                                    <span style="font-size:13px; color:#536471; margin-left:4px;"><%= ccount %></span>
                                </a>
                            </div>
                        </div>
                    </div>
                </article>
                <% } } %>
            </div>
        </div>

        <div class="home-side">
            <% if (isOwner) { %>
            <div class="card">
                <div class="section-title">받은 팔로우 요청</div>
                <% if (followRequests.isEmpty()) { %>
                    <div class="helper-text">받은 요청이 없습니다</div>
                <% } else {
                    for (Map<String,Object> row : followRequests) {
                        String reqId = (String) row.get("req_id");
                        String rid = (String) row.get("requester_id");
                        String rImg = (String) row.get("requester_img");
                %>
                    <div class="user-item">
                        <div style="margin-right:10px;">
                            <% if(rImg != null && !rImg.isEmpty()) { %>
                                <img src="uploads/<%= rImg %>" class="avatar-sm-img">
                            <% } else { %>
                                <div class="avatar-sm"><%= rid.substring(0,1).toUpperCase() %></div>
                            <% } %>
                        </div>
                        <div class="user-suggest-main">
                            <div class="user-name-row"><%= rid %></div>
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
                <% } } %>
            </div>
            <% } else { %>
                <div class="card">
                    <h3 class="section-title">추천 트렌드</h3>
                    <div class="helper-text">현재 인기 있는 주제를 확인해보세요.</div>
                </div>
            <% } %>
        </div>
    </div>
</div>
</body>
</html>
<% if (con != null) { try { con.close(); } catch (Exception ignore) {} } %>