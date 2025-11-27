<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.*, java.sql.*" %>
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

    if (currentUser == null || currentUser.trim().isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String initials = currentUser.substring(0,1).toUpperCase();

    String infoMessage = null;
    String errorMessage = null;

    // 액션 처리
    String action = request.getParameter("action");
    if (action != null) action = action.trim();

    try {
        if ("update_profile".equals(action)) {
            String addr  = request.getParameter("address");
            String phone = request.getParameter("phone_number");
            String sm    = request.getParameter("status_message");

            if (addr  != null) addr  = addr.trim();
            if (phone != null) phone = phone.trim();
            if (sm    != null) sm    = sm.trim();

            String usql =
                "UPDATE users " +
                "SET address = ?, phone_number = ?, status_message = ? " +
                "WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(usql)) {
                if (addr == null || addr.isEmpty())   ps.setNull(1, Types.VARCHAR);
                else                                  ps.setString(1, addr);
                if (phone == null || phone.isEmpty()) ps.setNull(2, Types.VARCHAR);
                else                                  ps.setString(2, phone);
                if (sm == null || sm.isEmpty())       ps.setNull(3, Types.VARCHAR);
                else                                  ps.setString(3, sm);
                ps.setString(4, currentUser);
                ps.executeUpdate();
            }
            infoMessage = "개인정보가 수정되었습니다";

        } else if ("update_privacy".equals(action)) {
            String priv = request.getParameter("is_private");
            String flag = "F";
            if ("T".equals(priv) || "on".equalsIgnoreCase(priv)) {
                flag = "T";
            }

            String psql =
                "UPDATE users SET is_private = ? WHERE user_id = ?";
            try (PreparedStatement ps = con.prepareStatement(psql)) {
                ps.setString(1, flag);
                ps.setString(2, currentUser);
                ps.executeUpdate();
            }
            if ("T".equals(flag)) {
                infoMessage = "비밀계정이 활성화되었습니다  이제 팔로워만 게시글을 볼 수 있습니다";
            } else {
                infoMessage = "비밀계정이 해제되었습니다  다시 공개 계정이 되었습니다";
            }

        }
        // 구독 결제는 기존처럼 subscribe.jsp에서 처리하므로 여기서는 건드리지 않음

    } catch (SQLIntegrityConstraintViolationException e) {
        errorMessage = "전화번호가 중복됩니다  다른 번호를 입력해 주세요";
    } catch (Exception e) {
        e.printStackTrace();
        errorMessage = "설정 변경 중 오류가 발생했습니다";
    }

    // 최신 유저 정보 읽기
    String address = null;
    String phone   = null;
    String status  = null;
    String paidStr = null;
    String isPrivate = "F";

    try {
        String q =
            "SELECT address, phone_number, status_message, paid, is_private " +
            "FROM users WHERE user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(q)) {
            ps.setString(1, currentUser);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    address   = rs.getString("address");
                    phone     = rs.getString("phone_number");
                    status    = rs.getString("status_message");
                    paidStr   = rs.getString("paid");
                    isPrivate = rs.getString("is_private");
                    if (isPrivate == null) isPrivate = "F";
                }
            }
        }
    } catch (Exception e) {
        e.printStackTrace();
        if (errorMessage == null) {
            errorMessage = "사용자 정보를 불러오는 중 오류가 발생했습니다";
        }
    }

    boolean isPaid = "T".equals(paidStr);
    session.setAttribute("currentUserPaid", isPaid);
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>설정  TWITTER_DB4</title>
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

    <div class="main-layout">
        <!-- 가운데 컬럼만 사용 -->
        <section class="column-center">
            <div class="card">
                <div style="display:flex; gap:16px; align-items:center; margin-bottom:12px;">
                    <div class="avatar-lg"><%= initials %></div>
                    <div>
                        <div class="post-username-row">
                            <span class="username-link"><%= currentUser %></span>
                            <%
                                if (isPaid) {
                            %>
                            <span class="badge-check">✓</span>
                            <%
                                }
                            %>
                        </div>
                        <div class="post-meta">
                            <%= (status == null || status.trim().isEmpty())
                                    ? "상태메시지 없음"
                                    : status %>
                        </div>
                        <div class="post-meta" style="margin-top:4px;">
                            계정 유형  
                            <strong><%= "T".equals(isPrivate) ? "비밀 계정" : "공개 계정" %></strong>
                        </div>
                    </div>
                </div>

                <% if (infoMessage != null) { %>
                    <div class="msg msg-ok"><%= infoMessage %></div>
                <% } %>
                <% if (errorMessage != null) { %>
                    <div class="msg msg-err"><%= errorMessage %></div>
                <% } %>
            </div>

            <!-- 개인정보 수정 -->
            <div class="card">
                <div class="section-title">개인정보 수정</div>
                <form method="post" action="settings.jsp">
                    <input type="hidden" name="action" value="update_profile">
                    <div class="form-row">
                        <label>주소</label>
                        <input type="text" name="address" class="form-input"
                               value="<%= address == null ? "" : address %>">
                    </div>
                    <div class="form-row">
                        <label>전화번호</label>
                        <input type="text" name="phone_number" class="form-input"
                               value="<%= phone == null ? "" : phone %>">
                    </div>
                    <div class="form-row">
                        <label>상태메시지</label>
                        <input type="text" name="status_message" class="form-input"
                               value="<%= status == null ? "" : status %>">
                    </div>
                    <div style="display:flex; justify-content:flex-end; margin-top:8px;">
                        <button type="submit" class="btn-primary">
                            저장
                        </button>
                    </div>
                </form>
            </div>

            <!-- 비밀계정 설정 -->
            <div class="card">
                <div class="section-title">비밀 계정 설정</div>
                <div class="helper-text" style="margin-bottom:8px;">
                    비밀 계정을 활성화하면 팔로워로 승인된 사용자만 회원님의 게시글을 볼 수 있습니다  
                    팔로우 요청은 회원님이 승인해야 팔로워가 됩니다
                </div>
                <form method="post" action="settings.jsp">
                    <input type="hidden" name="action" value="update_privacy">
                    <div class="form-row">
                        <label style="margin-right:12px;">
                            <input type="radio" name="is_private" value="F"
                                   <%= !"T".equals(isPrivate) ? "checked" : "" %>>
                            공개 계정
                        </label>
                        <label>
                            <input type="radio" name="is_private" value="T"
                                   <%= "T".equals(isPrivate) ? "checked" : "" %>>
                            비밀 계정
                        </label>
                    </div>
                    <div style="display:flex; justify-content:flex-end; margin-top:8px;">
                        <button type="submit" class="btn-secondary">
                            변경 적용
                        </button>
                    </div>
                </form>
            </div>

            <!-- 구독 설정 카드 -->
            <div class="card">
                <div class="section-title">구독 설정</div>
                <p class="helper-text">
                    유료 구독을 신청하거나 기간을 연장하려면 아래 버튼을 클릭하세요  
                </p>

                <a href="subscribe.jsp" class="btn-primary btn-sm">
                    구독 결제 페이지로 이동
                </a>
            </div>

            <!-- 계정 및 로그아웃 카드 -->
            <div class="card">
                <div class="section-title">로그아웃</div>
                <p class="helper-text">
                    현재 계정에서 로그아웃하려면 아래 로그아웃 버튼을 사용하세요  
                </p>

                <form method="post" action="logout.jsp">
                    <button type="submit" class="btn-danger btn-sm">
                        로그아웃
                    </button>
                </form>
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
