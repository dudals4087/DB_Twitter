<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");
    String currentUser = (String) session.getAttribute("currentUser");

    // 누구의 팔로잉을 볼 것인가?
    String profileUser = request.getParameter("user");
    if (profileUser == null || profileUser.isEmpty()) {
        if (currentUser != null) profileUser = currentUser;
        else { response.sendRedirect("login.jsp"); return; }
    }

    // 1. 내가(로그인한 사람) 팔로우한 목록 & 요청한 목록 미리 가져오기
    Set<String> myFollowings = new HashSet<>();
    Set<String> myRequests = new HashSet<>();

    if (currentUser != null) {
        try {
            String fSql = "SELECT user_id FROM followings WHERE follower_id = ?";
            try(PreparedStatement ps = con.prepareStatement(fSql)) {
                ps.setString(1, currentUser);
                try(ResultSet rs = ps.executeQuery()) {
                    while(rs.next()) myFollowings.add(rs.getString(1));
                }
            }
            String rSql = "SELECT target_id FROM follow_requests WHERE requester_id = ?";
            try(PreparedStatement ps = con.prepareStatement(rSql)) {
                ps.setString(1, currentUser);
                try(ResultSet rs = ps.executeQuery()) {
                    while(rs.next()) myRequests.add(rs.getString(1));
                }
            }
        } catch(Exception e) { e.printStackTrace(); }
    }

    // 2. 팔로잉 리스트 조회
    List<Map<String, String>> userList = new ArrayList<>();
    try {
        // [수정] ORDER BY f.created_at -> ORDER BY u.user_id
        String sql = "SELECT u.user_id, u.status_message, u.paid, u.profile_img " +
                     "FROM followings f " +
                     "JOIN users u ON u.user_id = f.user_id " + 
                     "WHERE f.follower_id = ? " + 
                     "ORDER BY u.user_id ASC";

        try(PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, profileUser);
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
    <title><%= profileUser %>의 팔로잉 / TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        .avatar-sm-img { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; border: 1px solid #cfd9de; }
        .btn-requested {
            background-color: #ffffff !important;
            border: 1px solid #cfd9de !important;
            color: #0f1419 !important;
            font-weight: bold;
        }
        .btn-requested:hover {
            background-color: #f7f9f9 !important;
            color: #f4212e !important;
        }
    </style>
</head>
<body>
<div class="app-shell">
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">팔로잉</div>
        </div>
        <div class="app-header-right">
            <a href="profile.jsp?user=<%= profileUser %>" class="icon-btn"><i class="fa-solid fa-arrow-left"></i></a>
        </div>
    </header>

    <div class="main-layout">
        <section class="column-center">
            <div class="card">
                <div class="section-title"><%= profileUser %>님이 따르는 사람들</div>
            </div>

            <div class="card">
                <% if (userList.isEmpty()) { %>
                    <div class="helper-text" style="padding:20px; text-align:center;">팔로잉하는 사람이 없습니다.</div>
                <% } else { 
                    for (Map<String, String> u : userList) {
                        String uid = u.get("user_id");
                        String stat = u.get("status_message");
                        String pImg = u.get("profile_img");
                        boolean isPaid = "T".equals(u.get("paid")); 
                        boolean isFollowing = myFollowings.contains(uid);
                        boolean isRequested = myRequests.contains(uid);
                        boolean isMe = (currentUser != null && currentUser.equals(uid));
                %>
                <div class="user-item" style="padding: 15px 0; border-bottom: 1px solid #eff3f4;">
                    <a href="profile.jsp?user=<%= uid %>" style="text-decoration:none;">
                        <% if(pImg != null && !pImg.isEmpty()) { %>
                            <img src="uploads/<%= pImg %>" class="avatar-sm-img" style="margin-right:12px;">
                        <% } else { %>
                            <div class="avatar-sm" style="margin-right:12px;"><%= uid.substring(0,1).toUpperCase() %></div>
                        <% } %>
                    </a>
                    <div class="user-suggest-main">
                        <div class="user-name-row">
                            <a href="profile.jsp?user=<%= uid %>" class="username-link"><%= uid %></a>
                            <% if (isPaid) { %> <span class="badge-check">✓</span> <% } %>
                        </div>
                        <div class="user-status"><%= (stat != null) ? stat : "" %></div>
                    </div>
                    <div>
                        <% if (currentUser != null && !isMe) { 
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