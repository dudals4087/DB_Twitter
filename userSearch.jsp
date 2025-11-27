<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean)session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String keyword = request.getParameter("q");
    if (keyword != null) keyword = keyword.trim();

    String errorMsg = null;

    class SimpleUser {
        String userId;
        String status;
        String paid;
        String isPrivate;
    }
    List<SimpleUser> results = new ArrayList<SimpleUser>();

    if (keyword != null && !keyword.isEmpty()) {
        try {
            String sql =
                "SELECT user_id, status_message, paid, is_private " +
                "FROM users " +
                "WHERE user_id LIKE ? " +
                "ORDER BY user_id " +
                "LIMIT 30";
            try (PreparedStatement ps = con.prepareStatement(sql)) {
                ps.setString(1, "%" + keyword + "%");
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        SimpleUser su = new SimpleUser();
                        su.userId     = rs.getString("user_id");
                        su.status     = rs.getString("status_message");
                        su.paid       = rs.getString("paid");
                        su.isPrivate  = rs.getString("is_private");
                        results.add(su);
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            errorMsg = "사용자를 검색하는 중 오류가 발생했습니다";
        }
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
    <title>사용자 검색  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">사용자 검색</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn">⚙</a>
                <a href="login.jsp" class="icon-btn">💬</a>
            <%
                } else {
            %>
                <a href="userSearch.jsp" class="icon-btn" title="사용자 검색">🔍</a>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= currentInitial %></a>
                <a href="settings.jsp" class="icon-btn">⚙</a>
                <a href="messages.jsp" class="icon-btn">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <div class="center-layout">
        <section class="center-column">
            <div class="card">
                <div class="section-title">사용자 검색</div>
                <form method="get" action="userSearch.jsp" style="margin-bottom:16px;">
                    <div class="comment-write-row">
                        <input type="text"
                               name="q"
                               class="comment-input"
                               placeholder="아이디 일부를 입력하세요"
                               value="<%= (keyword == null ? "" : keyword) %>">
                        <button type="submit" class="btn-primary btn-sm">검색</button>
                    </div>
                </form>

                <%
                    if (errorMsg != null) {
                %>
                    <div class="msg msg-err"><%= errorMsg %></div>
                <%
                    } else if (keyword == null || keyword.isEmpty()) {
                %>
                    <div class="helper-text">위 검색창에 아이디를 입력해 보세요</div>
                <%
                    } else if (results.isEmpty()) {
                %>
                    <div class="helper-text">"<%= keyword %>" 에 대한 검색 결과가 없습니다</div>
                <%
                    } else {
                %>
                    <div class="section-title" style="margin-top:4px;">
                        "<%= keyword %>" 검색 결과 <%= results.size() %>명
                    </div>
                    <%
                        for (SimpleUser su : results) {
                            String uid  = su.userId;
                            String init = uid.substring(0,1).toUpperCase();
                            boolean paid = "T".equals(su.paid);
                            boolean priv = "T".equals(su.isPrivate);
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
                                        if (priv) {
                                    %>
                                        <span class="badge-pill">🔒</span>
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
