<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean)session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String profileUser = request.getParameter("user");
    if (profileUser != null) profileUser = profileUser.trim();

    String errorMsg = null;
    if (profileUser == null || profileUser.isEmpty()) {
        errorMsg = "어떤 사용자의 팔로워를 볼지 알 수 없습니다";
    }

    String initials = "U";
    if (profileUser != null && profileUser.length() > 0) {
        initials = profileUser.substring(0,1).toUpperCase();
    }

    boolean isOwner = (currentUser != null && currentUser.equals(profileUser));
    boolean alreadyFollowing = false;
    boolean profilePrivate   = false;
    boolean profilePaid      = false;
    String  statusMsg        = null;

    class SimpleUser {
        String userId;
        String status;
        String paid;
    }
    List<SimpleUser> followers = new ArrayList<SimpleUser>();

    try {
        if (errorMsg == null) {
            // 대상 유저 정보
            String usql =
                "SELECT status_message, paid, is_private " +
                "FROM users WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(usql)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        statusMsg      = rs.getString("status_message");
                        profilePaid    = "T".equals(rs.getString("paid"));
                        profilePrivate = "T".equals(rs.getString("is_private"));
                    } else {
                        errorMsg = "해당 사용자를 찾을 수 없습니다";
                    }
                }
            }
        }

        // 내가 이 사람을 팔로우 중인지
        if (errorMsg == null && currentUser != null && !isOwner) {
            String chk =
                "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
            try (PreparedStatement ps = con.prepareStatement(chk)) {
                ps.setString(1, currentUser);
                ps.setString(2, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) alreadyFollowing = true;
                }
            }
        }

        // 비밀계정이면 본인 혹은 팔로우한 사람만 목록 조회 가능
        boolean canViewList = true;
        if (profilePrivate && !isOwner) {
            if (currentUser == null) {
                canViewList = false;
            } else if (!alreadyFollowing) {
                canViewList = false;
            }
        }

        if (errorMsg == null && canViewList) {
            // 팔로워 목록
            // followings: user_id = 팔로워, follower_id = 내가 팔로우하는 계정
            String fsql =
                "SELECT u.user_id, u.status_message, u.paid " +
                "FROM followings f " +
                "JOIN users u ON u.user_id = f.user_id " +
                "WHERE f.follower_id = ? " +
                "ORDER BY u.user_id";
            try (PreparedStatement ps = con.prepareStatement(fsql)) {
                ps.setString(1, profileUser);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        SimpleUser su = new SimpleUser();
                        su.userId = rs.getString("user_id");
                        su.status = rs.getString("status_message");
                        su.paid   = rs.getString("paid");
                        followers.add(su);
                    }
                }
            }
        }

        if (errorMsg == null && profilePrivate && !isOwner && !alreadyFollowing) {
            errorMsg = "비밀계정이에요 팔로우한 사람만 팔로워를 볼 수 있습니다";
        }

    } catch (Exception e) {
        e.printStackTrace();
        if (errorMsg == null) errorMsg = "팔로워 정보를 불러오는 중 오류가 발생했습니다";
    }

    String currentInitial = "G";
    if (currentUser != null && currentUser.length() > 0) {
        currentInitial = currentUser.substring(0,1).toUpperCase();
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title><%= profileUser %> 님의 팔로워  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub"><%= profileUser %> 님의 팔로워</div>
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

    <div class="center-layout">
        <section class="center-column">
            <div class="card">
                <form action="profile.jsp" method="get" style="margin-bottom:12px;">
                    <input type="hidden" name="user" value="<%= profileUser %>">
                    <button type="submit" class="btn-secondary btn-sm">
                        ← <%= profileUser %> 프로필로 돌아가기
                    </button>
                </form>

                <%
                    if (errorMsg != null) {
                %>
                    <div class="msg msg-err"><%= errorMsg %></div>
                <%
                    } else {
                %>
                    <div class="section-title"><%= profileUser %> 님의 팔로워</div>
                    <%
                        if (followers.isEmpty()) {
                    %>
                        <div class="helper-text">아직 팔로워가 없습니다</div>
                    <%
                        } else {
                            for (SimpleUser su : followers) {
                                String uid   = su.userId;
                                String init  = uid.substring(0,1).toUpperCase();
                                boolean paid = "T".equals(su.paid);
                    %>
                        <div class="user-item">
                            <a href="profile.jsp?user=<%= uid %>" class="avatar-sm-link">
                                <div class="avatar-sm"><%= init %></div>
                            </a>
                            <div class="user-suggest-main">
                                <div class="user-name-row">
                                    <a href="profile.jsp?user=<%= uid %>" class="username-link"><%= uid %></a>
                                    <%
                                        if (paid) {
                                    %>
                                        <span class="badge-check">✓</span>
                                    <%
                                        }
                                    %>
                                </div>
                                <div class="user-status">
                                    <%= (su.status == null || su.status.trim().isEmpty())
                                            ? "상태메시지 없음"
                                            : su.status %>
                                </div>
                            </div>
                        </div>
                    <%
                            }
                        }
                    }
                    %>
            </div>
        </section>
    </div>

</div>
</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>
