<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");

    String searchId = request.getParameter("searchId");
    if (searchId != null) searchId = searchId.trim();

    // 1. 내가 팔로우/요청한 목록 조회
    Set<String> myFollowings = new HashSet<>();
    Set<String> myRequests = new HashSet<>();

    if (currentUser != null) {
        try {
            // [A] 이미 팔로우 중인 사람 목록
            String fSql = "SELECT user_id FROM followings WHERE follower_id = ?";
            try(PreparedStatement ps = con.prepareStatement(fSql)) {
                ps.setString(1, currentUser);
                try(ResultSet rs = ps.executeQuery()) {
                    while(rs.next()) myFollowings.add(rs.getString(1));
                }
            }
            // [B] 팔로우 요청 보낸 사람 목록 (비공개 계정)
            String rSql = "SELECT target_id FROM follow_requests WHERE requester_id = ?";
            try(PreparedStatement ps = con.prepareStatement(rSql)) {
                ps.setString(1, currentUser);
                try(ResultSet rs = ps.executeQuery()) {
                    while(rs.next()) myRequests.add(rs.getString(1));
                }
            }
        } catch(Exception e) { e.printStackTrace(); }
    }

    // 2. 사용자 리스트 조회
    List<Map<String, String>> userList = new ArrayList<>();
    try {
        String sql = "";
        if (searchId != null && !searchId.isEmpty()) {
            sql = "SELECT user_id, status_message, paid, profile_img FROM users WHERE user_id LIKE ? AND user_id <> ? ORDER BY user_id ASC";
        } else {
            sql = "SELECT user_id, status_message, paid, profile_img FROM users WHERE user_id <> ? ORDER BY user_id ASC LIMIT 20";
        }

        try(PreparedStatement ps = con.prepareStatement(sql)) {
            if (searchId != null && !searchId.isEmpty()) {
                ps.setString(1, "%" + searchId + "%");
                ps.setString(2, (currentUser == null) ? "" : currentUser);
            } else {
                ps.setString(1, (currentUser == null) ? "" : currentUser);
            }

            try(ResultSet rs = ps.executeQuery()) {
                while(rs.next()) {
                    Map<String, String> map = new HashMap<>();
                    map.put("user_id", rs.getString("user_id"));
                    map.put("status_message", rs.getString("status_message"));
                    map.put("paid", rs.getString("paid"));
                    map.put("profile_img", rs.getString("profile_img"));
                    userList.add(map);
                }
            }
        }
    } catch(Exception e) { e.printStackTrace(); }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>팔로우 추천 / TWITTER_DB4</title>
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
        /* 버튼 스타일 강제 적용을 위한 클래스 */
        .btn-requested {
            background-color: #ffffff !important;
            border: 1px solid #cfd9de !important;
            color: #0f1419 !important; /* 검은색 글씨 */
            font-weight: bold;
        }
        .btn-requested:hover {
            background-color: #f7f9f9 !important;
            border-color: #cfd9de !important;
            color: #f4212e !important; /* 호버 시 빨간색(취소 느낌) */
            content: '취소'; /* CSS로 텍스트 변경은 어렵지만 색상은 변경 가능 */
        }
    </style>
</head>
<body>
<div class="app-shell">
    
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">팔로우 추천</div>
        </div>
        <div class="app-header-right">
            <a href="main.jsp" class="icon-btn"><i class="fa-solid fa-house"></i></a>
        </div>
    </header>

    <div class="main-layout">
        <section class="column-center">
            
            <div class="card">
                <div class="section-title">마음에 드는 사람을 팔로우해보세요.</div>
                <div class="search-container" style="position:static; margin-top:15px; background:transparent; padding:0;">
                    <form action="followList.jsp" method="get">
                        <div class="search-bar-wrapper">
                            <i class="fa-solid fa-magnifying-glass search-icon-inside"></i>
                            <input type="text" name="searchId" class="search-input-rounded" 
                                   placeholder="사용자 검색" value="<%= (searchId!=null)?searchId:"" %>">
                        </div>
                    </form>
                </div>
            </div>

            <div class="card">
                <% if (userList.isEmpty()) { %>
                    <div class="helper-text" style="padding:20px; text-align:center;">
                        검색 결과가 없습니다.
                    </div>
                <% } else { 
                    for (Map<String, String> u : userList) {
                        String uid = u.get("user_id");
                        String stat = u.get("status_message");
                        String pImg = u.get("profile_img");
                        
                        boolean isPaid = "T".equals(u.get("paid")); 
                        boolean isFollowing = myFollowings.contains(uid);
                        boolean isRequested = myRequests.contains(uid);
                %>
                <div class="user-item" style="padding: 15px 0; border-bottom: 1px solid #eff3f4;">
                    <a href="profile.jsp?user=<%= uid %>" style="text-decoration:none;">
                        <% if(pImg != null && !pImg.isEmpty()) { %>
                            <img src="uploads/<%= pImg %>" class="avatar-sm-img" style="margin-right:12px;">
                        <% } else { %>
                            <div class="avatar-sm" style="margin-right:12px;">
                                <%= uid.substring(0,1).toUpperCase() %>
                            </div>
                        <% } %>
                    </a>

                    <div class="user-suggest-main">
                        <div class="user-name-row">
                            <a href="profile.jsp?user=<%= uid %>" class="username-link"><%= uid %></a>
                            <% if (isPaid) { %> <span class="badge-check">✓</span> <% } %>
                        </div>
                        <div class="user-status">
                            <%= (stat != null && !stat.isEmpty()) ? stat : "상태메시지 없음" %>
                        </div>
                    </div>

                    <div>
                        <% if (currentUser == null) { %>
                            <a href="login.jsp" class="btn-primary btn-sm">팔로우</a>
                        <% } else { 
                             if (isFollowing) { %>
                                <form method="post" action="followUser.jsp" style="margin:0;">
                                    <input type="hidden" name="target_id" value="<%= uid %>">
                                    <button type="submit" class="btn-secondary btn-sm" style="width:80px;">팔로잉</button>
                                </form>
                            <% } else if (isRequested) { %>
                                <form method="post" action="followUser.jsp" style="margin:0;">
                                    <input type="hidden" name="target_id" value="<%= uid %>">
                                    <button type="submit" class="btn-secondary btn-sm btn-requested" style="width:80px;">요청 취소</button>
                                </form>
                            <% } else { %>
                                <form method="post" action="followUser.jsp" style="margin:0;">
                                    <input type="hidden" name="target_id" value="<%= uid %>">
                                    <button type="submit" class="btn-primary btn-sm" style="width:80px;">팔로우</button>
                                </form>
                        <%   } 
                           } %>
                    </div>
                </div>
                <%   } 
                   } %>
            </div>

        </section>
    </div>
</div>
</body>
</html>
<% if (con != null) { try { con.close(); } catch(Exception e) {} } %>